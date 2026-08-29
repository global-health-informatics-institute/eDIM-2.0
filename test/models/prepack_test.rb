require 'test_helper'

class PrepackTest < ActiveSupport::TestCase
  setup do
    User.current = User.create!(username: 'tester', password: 'password')
    @drug = Drug.create!(name: 'Test Drug', dose_form: 'tablet')
    @bottle = GeneralInventory.create!(
      drug_id: @drug.drug_id,
      expiration_date: 1.year.from_now.to_date,
      date_received: Date.current,
      received_quantity: 100,
      current_quantity: 100,
      location_id: 1
    )
  end

  teardown do
    User.current = nil
  end

  test 'pack status is damaged when every pack is damaged' do
    prepack = create_prepack
    create_label(prepack, 'PK-G000001-1', voided: true)
    create_label(prepack, 'PK-G000001-2', voided: true)

    prepack.sync_pack_status!

    assert_equal 'damaged', prepack.reload.status
    assert_equal 0, prepack.current_num_packs
  end

  test 'pack status is done when every pack is dispensed' do
    prepack = create_prepack
    create_label(prepack, 'PK-G000002-1', dispensed: true)
    create_label(prepack, 'PK-G000002-2', dispensed: true)

    prepack.sync_pack_status!

    assert_equal 'dispensed', prepack.reload.status
    assert_equal 0, prepack.current_num_packs
  end

  test 'pack status is done when completed packs are mixed damaged and dispensed' do
    prepack = create_prepack
    create_label(prepack, 'PK-G000003-1', voided: true)
    create_label(prepack, 'PK-G000003-2', dispensed: true)

    prepack.sync_pack_status!

    assert_equal 'dispensed', prepack.reload.status
    assert_equal 0, prepack.current_num_packs
  end

  test 'pack status remains active while at least one pack is available' do
    prepack = create_prepack
    create_label(prepack, 'PK-G000004-1', voided: true)
    create_label(prepack, 'PK-G000004-2', dispensed: true)
    create_label(prepack, 'PK-G000004-3')

    prepack.sync_pack_status!

    assert_equal 'active', prepack.reload.status
    assert_equal 1, prepack.current_num_packs
  end

  private

  def create_prepack
    Prepack.create!(
      bottle_id: @bottle.gn_inventory_id,
      gn_identifier: @bottle.gn_identifier,
      drug_id: @drug.drug_id,
      quantity_per_pack: 10,
      num_packs: 2,
      total_quantity: 20,
      prepacked_by_id: User.current.user_id,
      location_id: 1
    )
  end

  def create_label(prepack, label_identifier, attrs = {})
    PrepackLabel.create!(
      {
        prepack_id: prepack.id,
        bottle_id: @bottle.gn_inventory_id,
        label_identifier: label_identifier
      }.merge(attrs)
    )
  end
end
