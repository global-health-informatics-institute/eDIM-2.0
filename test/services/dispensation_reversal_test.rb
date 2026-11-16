require 'test_helper'
require 'minitest/mock'
require_relative '../support/pack_dispensing_records'

class DispensationReversalTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  include PackDispensingRecords

  setup { create_pack_records }
  teardown { User.current = nil }

  def reverse(dispensation, **overrides)
    DispensationReversal.call(**{
      dispensation_id: dispensation.id, reason: 'wrong_pack', notes: 'Selected by mistake',
      user: @user, location_id: 1
    }.merge(overrides))
  end

  def bottle_dispensation(quantity: 10, prescription: nil)
    prescription ||= Prescription.create!(patient_id: @patient.id, drug_id: @drug.id,
                                           quantity: quantity, amount_dispensed: quantity)
    Dispensation.create!(dispensation_type: 'bottle', inventory_id: @bottle.id,
                         patient_id: @patient.id, rx_id: prescription.id,
                         quantity: quantity, dispensed_by: @user.id, dispensation_date: Time.current)
  end

  test 'a reversed pack can be dispensed again with its original history preserved' do
    original = dispense_pack
    dispense_pack(@other_label)
    assert_equal 'dispensed', @prepack.reload.status

    reversed = reverse(original)

    assert reversed.voided?
    assert_equal 'wrong_pack', reversed.reversal_reason
    assert_equal 'Selected by mistake', reversed.reversal_notes
    assert_equal @user.id, reversed.reversed_by_id
    assert_not_nil reversed.reversed_at
    assert_equal @patient.id, reversed.patient_id
    assert_equal @label.id, reversed.prepack_label_id
    assert_not @label.reload.dispensed?
    assert_nil @label.patient_id
    assert_nil @label.dispensed_by
    assert_nil @label.date_dispensed
    assert_equal 'available', @prepack.reload.status
    assert_equal 0, @bottle.reload.current_quantity
    assert_equal 0, original.prescription.reload.amount_dispensed

    next_patient = EdimPatient.create!(full_name: 'Another Test Patient')
    next_dispensation = dispense_pack(@label, patient_id: next_patient.id)
    assert_not_equal original.id, next_dispensation.id
    assert_equal @label.id, next_dispensation.prepack_label_id
    assert_equal next_patient.id.to_s, @label.reload.patient_id
    assert_equal @patient.id, original.reload.patient_id
    assert original.voided?
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'a bottle reversal restores only its quantity and reduces its prescription total' do
    original = bottle_dispensation
    @bottle.update!(current_quantity: 5)

    reverse(original, reason: 'wrong_medication', notes: nil)

    assert_equal 15, @bottle.reload.current_quantity
    assert_equal 0, original.prescription.reload.amount_dispensed
    assert_nil original.reload.reversal_notes
    assert_not @label.reload.dispensed?
  end

  test 'reversing one of multiple bottle entries leaves the other entry active' do
    prescription = Prescription.create!(patient_id: @patient.id, drug_id: @drug.id,
                                         quantity: 15, amount_dispensed: 15)
    first = bottle_dispensation(quantity: 10, prescription: prescription)
    second = bottle_dispensation(quantity: 5, prescription: prescription)

    reverse(first)

    assert_equal 10, @bottle.reload.current_quantity
    assert_equal 5, prescription.reload.amount_dispensed
    assert_not second.reload.voided?
  end

  test 'repeated reversal never restores bottle stock twice' do
    original = bottle_dispensation
    reverse(original)
    timestamp = original.reload.reversed_at

    assert_raises(DispensationReversal::AlreadyReversed) { reverse(original) }
    assert_equal 10, @bottle.reload.current_quantity
    assert_equal timestamp, original.reload.reversed_at
    assert_equal 0, original.prescription.reload.amount_dispensed
  end

  test 'reversing an old entry again cannot release a pack assigned to another patient' do
    original = dispense_pack
    reverse(original)
    next_patient = EdimPatient.create!(full_name: 'Another Test Patient')
    dispense_pack(@label, patient_id: next_patient.id)

    assert_raises(DispensationReversal::AlreadyReversed) { reverse(original) }
    assert @label.reload.dispensed?
    assert_equal next_patient.id.to_s, @label.patient_id
  end

  test 'unknown historical records and barcode inventory references require reconciliation' do
    unknown = Dispensation.new(quantity: 10, inventory_id: @bottle.id)
    unknown.save!(validate: false)
    assert_raises(DispensationReversal::Error) { reverse(unknown) }

    bottle = bottle_dispensation
    bottle.update!(inventory_id: @bottle.gn_identifier)
    assert_raises(DispensationReversal::Error) { reverse(bottle) }
    assert_equal 0, @bottle.reload.current_quantity
    assert_not unknown.reload.voided?
    assert_not bottle.reload.voided?
  end

  test 'reason notes user and location are validated before changing the pack' do
    original = dispense_pack
    [{reason: ''}, {reason: 'unrecognized'}, {reason: 'other', notes: ' '},
     {user: nil}, {location_id: nil}, {location_id: 2}].each do |overrides|
      assert_raises(DispensationReversal::Error) { reverse(original, **overrides) }
    end
    assert @label.reload.dispensed?
    assert_not original.reload.voided?
  end

  test 'other reasons preserve the supplied notes' do
    original = dispense_pack
    reverse(original, reason: 'other', notes: '  Entered in error  ')

    assert_equal 'Entered in error', original.reload.reversal_notes
  end

  test 'inconsistent label assignments cannot be released' do
    original = dispense_pack
    @label.update!(patient_id: '-1')

    assert_raises(DispensationReversal::Error) { reverse(original) }
    assert @label.reload.dispensed?
    assert_not original.reload.voided?
  end

  test 'a damaged pack cannot be made available by reversing it' do
    original = dispense_pack
    @label.update!(voided: true)

    assert_raises(DispensationReversal::Error) { reverse(original) }
    assert @label.reload.voided?
    assert @label.dispensed?
  end

  test 'reversal can correct an expired pack entry but it still cannot be dispensed again' do
    original = dispense_pack
    @bottle.update!(expiration_date: Date.current)
    reverse(original)

    assert_not @label.reload.dispensed?
    assert_raises(PackDispensation::ExpiredPack) { dispense_pack }
  end

  test 'inconsistent prescription quantities do not change inventory' do
    original = bottle_dispensation
    original.prescription.update!(amount_dispensed: 5)

    assert_raises(DispensationReversal::Error) { reverse(original) }
    assert_equal 0, @bottle.reload.current_quantity
    assert_not original.reload.voided?
  end

  test 'a failed prescription update rolls back the label and audit changes' do
    original = dispense_pack
    prescription = original.prescription
    locked = Minitest::Mock.new
    locked.expect(:find, prescription, [prescription.id])
    Prescription.stub(:lock, locked) do
      prescription.stub(:update!, ->(**) { raise ActiveRecord::RecordInvalid.new(prescription) }) do
        assert_raises(ActiveRecord::RecordInvalid) { reverse(original) }
      end
    end
    locked.verify

    assert @label.reload.dispensed?
    assert_not original.reload.voided?
    assert_nil original.reversed_at
    assert_equal 10, prescription.reload.amount_dispensed
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'a pack can be reversed just before the 24-hour deadline' do
    original = dispense_pack
    travel_to(original.dispensation_date + 24.hours - 1.second)

    reverse(original)

    assert original.reload.voided?
    assert_not @label.reload.dispensed?
  end

  test 'pack reversal is blocked exactly at the 24-hour deadline' do
    original = dispense_pack
    travel_to(original.dispensation_date + 24.hours)

    error = assert_raises(DispensationReversal::Error) { reverse(original) }

    assert_match(/24-hour reversal window has expired/, error.message)
    assert_not original.reload.voided?
    assert @label.reload.dispensed?
    assert_equal 10, original.prescription.reload.amount_dispensed
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'bottle reversal after 24 hours cannot restore stock' do
    original = bottle_dispensation
    travel_to(original.dispensation_date + 24.hours + 1.second)

    assert_raises(DispensationReversal::Error) { reverse(original) }
    assert_not original.reload.voided?
    assert_equal 0, @bottle.reload.current_quantity
    assert_equal 10, original.prescription.reload.amount_dispensed
  end

  test 'missing or future dispensation times need reconciliation' do
    original = bottle_dispensation
    [nil, 1.hour.from_now].each do |timestamp|
      original.update!(dispensation_date: timestamp)
      assert_raises(DispensationReversal::Error) { reverse(original) }
    end
    assert_not original.reload.voided?
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'reversal is rejected if the deadline passes while acquiring locks' do
    original = dispense_pack
    prescription = original.prescription
    travel_to(original.dispensation_date + 24.hours - 1.second)
    locked = Object.new
    # The lock lookup changes the clock before returning the prescription.
    test_case = self
    locked.define_singleton_method(:find) do |_id|
      test_case.travel_to(original.dispensation_date + 24.hours)
      prescription
    end
    Prescription.stub(:lock, locked) do
      assert_raises(DispensationReversal::Error) { reverse(original) }
    end

    assert_not original.reload.voided?
    assert @label.reload.dispensed?
    assert_equal 10, prescription.reload.amount_dispensed
  end
end
