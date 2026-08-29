require 'test_helper'

class GeneralInventoryTest < ActiveSupport::TestCase
  setup do
    User.current = User.create!(username: 'tester', password: 'password')
    @drug_category = DrugCategory.create!(category: 'Test Category')
    @drug = Drug.create!(name: 'Test Drug', dose_form: 'tablet', drug_category_id: @drug_category.drug_category_id)
  end

  teardown do
    User.current = nil
  end

  test "should be valid with future expiration date" do
    inventory = GeneralInventory.new(
      drug_id: @drug.drug_id,
      expiration_date: Date.tomorrow,
      date_received: Date.current,
      received_quantity: 10,
      current_quantity: 10,
      location_id: 1
    )
    assert inventory.valid?
  end

  test "should be invalid with today as expiration date" do
    inventory = GeneralInventory.new(
      drug_id: @drug.drug_id,
      expiration_date: Date.current,
      date_received: Date.current,
      received_quantity: 10,
      current_quantity: 10,
      location_id: 1
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:expiration_date], "must be a future date"
  end

  test "should be invalid with past expiration date" do
    inventory = GeneralInventory.new(
      drug_id: @drug.drug_id,
      expiration_date: Date.yesterday,
      date_received: Date.current,
      received_quantity: 10,
      current_quantity: 10,
      location_id: 1
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:expiration_date], "must be a future date"
  end

  test "should allow updating existing record without changing expiration date" do
    inventory = GeneralInventory.create!(
      drug_id: @drug.drug_id,
      expiration_date: Date.tomorrow,
      date_received: Date.current,
      received_quantity: 10,
      current_quantity: 10,
      location_id: 1
    )

    inventory.current_quantity = 5
    assert inventory.valid?
  end

  test "should not allow updating expiration date to past" do
    inventory = GeneralInventory.create!(
      drug_id: @drug.drug_id,
      expiration_date: Date.tomorrow,
      date_received: Date.current,
      received_quantity: 10,
      current_quantity: 10,
      location_id: 1
    )

    inventory.expiration_date = Date.yesterday
    assert_not inventory.valid?
    assert_includes inventory.errors[:expiration_date], "must be a future date"
  end
end
