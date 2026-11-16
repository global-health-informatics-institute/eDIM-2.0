require 'test_helper'
require 'minitest/mock'
require_relative '../support/pack_dispensing_records'

class PackDispensationTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  include PackDispensingRecords

  setup { create_pack_records }
  teardown { User.current = nil }

  test 'dispensing a prepared pack records the label without changing loose stock' do
    visit = EdimVisit.create!(edim_patient: @patient, visit_date: Date.current,
                             arrival_time: 1.hour.ago, identifier: 'PACK-TEST')
    dispensation = dispense_pack

    assert_equal 0, @bottle.reload.current_quantity
    assert dispensation.dispensation_type_pack?
    assert_equal @label.id, dispensation.prepack_label_id
    assert_equal @bottle.id.to_s, dispensation.inventory_id
    assert_equal @patient.id, dispensation.patient_id
    assert_equal 10, dispensation.quantity
    assert_equal 10, dispensation.prescription.amount_dispensed
    assert_equal ['morning'], JSON.parse(dispensation.prescription.times)
    assert @label.reload.dispensed?
    assert_equal @patient.id.to_s, @label.patient_id
    assert_equal @user.id, @label.dispensed_by
    assert_equal dispensation.dispensation_date, @label.date_dispensed
    assert_equal dispensation.dispensation_date, visit.reload.departure_time
    assert_equal 'available', @prepack.reload.status
  end

  test 'a repeated scan cannot create another prescription or dispensation' do
    dispense_pack

    assert_no_difference ['Prescription.count', 'Dispensation.count'] do
      assert_raises(PackDispensation::Error) { dispense_pack }
    end
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'dispensing a prepared pack leaves remaining loose stock unchanged' do
    @bottle.update!(current_quantity: 20)

    dispense_pack

    assert_equal 20, @bottle.reload.current_quantity
  end

  test 'an inconsistent label with an active dispensation cannot be reused' do
    dispense_pack
    @label.update_columns(dispensed: false)

    assert_no_difference ['Prescription.count', 'Dispensation.count'] do
      assert_raises(PackDispensation::Error) { dispense_pack }
    end
  end

  test 'voided and deleted labels cannot be dispensed' do
    [@label, @other_label].zip([:voided, :deleted]).each do |label, flag|
      label.update!(flag => true)
      assert_raises(PackDispensation::Error) { dispense_pack(label) }
    end
    assert_equal 0, Dispensation.count
  end

  test 'voided and deleted batches cannot be dispensed' do
    [:voided, :deleted].each do |flag|
      @prepack.update!(flag => true)
      assert_raises(PackDispensation::Error) { dispense_pack }
      @prepack.update!(flag => false)
    end
    assert_not @label.reload.dispensed?
  end

  test 'wrong location and missing patient or user cannot dispense a pack' do
    [{location_id: 2}, {location_id: nil}, {patient_id: nil},
     {patient_id: -1}, {user: nil}].each do |overrides|
      assert_raises(PackDispensation::Error) { dispense_pack(**overrides) }
    end
    assert_not @label.reload.dispensed?
    assert_equal 0, Dispensation.count
  end

  test 'expired or voided source bottles cannot dispense a pack' do
    @bottle.update!(expiration_date: Date.current)
    assert_raises(PackDispensation::ExpiredPack) { dispense_pack }
    @bottle.update!(expiration_date: Date.current + 30, voided: true)
    assert_raises(PackDispensation::Error) { dispense_pack }
    assert_not @label.reload.dispensed?
  end

  test 'last available label completes the batch even when another label was damaged' do
    @other_label.update!(voided: true)
    dispense_pack

    assert_equal 'dispensed', @prepack.reload.status
    assert_equal 2, @prepack.current_num_packs
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'invalid dosing times leave the pack and all records unchanged' do
    @prepack.update!(times: 'invalid json')

    assert_no_difference ['Prescription.count', 'Dispensation.count'] do
      assert_raises(PackDispensation::Error) { dispense_pack }
    end
    assert_not @label.reload.dispensed?
  end

  test 'failure after creating a prescription rolls back the transaction' do
    original_status = @prepack.status
    Dispensation.stub(:create!, ->(**) { raise ActiveRecord::RecordInvalid.new(Dispensation.new) }) do
      assert_no_difference ['Prescription.count', 'Dispensation.count'] do
        assert_raises(ActiveRecord::RecordInvalid) { dispense_pack }
      end
    end
    assert_not @label.reload.dispensed?
    assert_equal original_status, @prepack.reload.status
    assert_equal 0, @bottle.reload.current_quantity
  end
end

class PackDispensationConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false
  include PackDispensingRecords

  setup { create_pack_records }
  teardown do
    label_ids = [@label.id, @other_label.id]
    dispensations = Dispensation.where(inventory_id: @bottle.id.to_s)
    prescription_ids = dispensations.pluck(:rx_id)
    dispensations.delete_all
    Prescription.where(rx_id: prescription_ids).delete_all
    PrepackLabel.where(id: label_ids).delete_all
    Prepack.where(id: @prepack.id).delete_all
    GeneralInventory.where(gn_inventory_id: @bottle.id).delete_all
    Drug.where(drug_id: @drug.id).delete_all
    EdimPatient.where(patient_id: @patient.id).delete_all
    User.where(user_id: @user.id).delete_all
    User.current = nil
  end

  test 'simultaneous scans of the same label create only one dispensation' do
    results = dispense_concurrently([@label, @label])

    assert_equal 1, results.count { |result| result.is_a?(Dispensation) }
    assert_equal 1, results.count { |result| result.is_a?(PackDispensation::Error) }
    assert_equal 1, Dispensation.where(prepack_label_id: @label.id).count
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'simultaneous scans of different labels correctly complete the batch' do
    results = dispense_concurrently([@label, @other_label])

    assert results.all? { |result| result.is_a?(Dispensation) }, results.inspect
    assert_equal 2, Dispensation.where(prepack_label_id: [@label.id, @other_label.id]).count
    assert_equal 'dispensed', @prepack.reload.status
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'simultaneous reversals release a pack only once' do
    original = dispense_pack
    results = run_concurrently([original.id, original.id]) do |id|
      DispensationReversal.call(dispensation_id: id, reason: 'wrong_pack', user: @user, location_id: 1)
    end

    assert_equal 1, results.count { |result| result.is_a?(Dispensation) }
    assert_equal 1, results.count { |result| result.is_a?(DispensationReversal::AlreadyReversed) }
    assert_not @label.reload.dispensed?
    assert_equal 0, original.prescription.reload.amount_dispensed
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'simultaneous bottle reversals restore stock only once' do
    prescription = Prescription.create!(patient_id: @patient.id, drug_id: @drug.id,
                                         quantity: 10, amount_dispensed: 10)
    original = Dispensation.create!(dispensation_type: 'bottle', inventory_id: @bottle.id,
                                    patient_id: @patient.id, rx_id: prescription.id, quantity: 10,
                                    dispensation_date: Time.current)
    results = run_concurrently([original.id, original.id]) do |id|
      DispensationReversal.call(dispensation_id: id, reason: 'wrong_medication', user: @user, location_id: 1)
    end

    assert_equal 1, results.count { |result| result.is_a?(Dispensation) }
    assert_equal 1, results.count { |result| result.is_a?(DispensationReversal::AlreadyReversed) }
    assert_equal 10, @bottle.reload.current_quantity
    assert_equal 0, prescription.reload.amount_dispensed
  end

  test 'a scan racing with reversal cannot create two active assignments' do
    original = dispense_pack
    actions = [
      -> { dispense_pack },
      -> { DispensationReversal.call(dispensation_id: original.id, reason: 'wrong_pack', user: @user, location_id: 1) }
    ]
    run_concurrently(actions) { |action| action.call }

    active = Dispensation.where(prepack_label_id: @label.id, voided: false).count
    assert_operator active, :<=, 1
    assert_equal active == 1, @label.reload.dispensed?
    assert original.reload.voided?
    assert_equal 0, @bottle.reload.current_quantity
  end

  private

  def dispense_concurrently(labels)
    run_concurrently(labels) { |label| dispense_pack(label) }
  end

  def run_concurrently(items)
    ready = Queue.new
    start = Queue.new
    threads = items.map do |item|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          begin
            yield item
          rescue PackDispensation::Error, DispensationReversal::Error => e
            e
          end
        end
      end
    end
    items.size.times { ready.pop }
    items.size.times { start << true }
    threads.map(&:value)
  end
end
