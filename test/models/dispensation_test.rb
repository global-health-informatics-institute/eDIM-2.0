require 'test_helper'

class DispensationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test 'new dispensations must identify their source' do
    dispensation = Dispensation.new
    dispensation.valid?

    assert dispensation.dispensation_type_unknown?
    assert dispensation.errors.of_kind?(:dispensation_type, :inclusion)
  end

  test 'new dispensations cannot omit their source explicitly' do
    dispensation = Dispensation.new(dispensation_type: nil)
    dispensation.valid?

    assert dispensation.errors.of_kind?(:dispensation_type, :inclusion)
  end

  test 'historical unknown dispensations can still be updated' do
    dispensation = Dispensation.new(quantity: 10)
    dispensation.save!(validate: false)
    dispensation.reload.update!(quantity: 12)

    assert dispensation.dispensation_type_unknown?
    assert_equal 12, dispensation.reload.quantity
    assert_empty dispensation.errors[:dispensation_type]
    assert_empty dispensation.errors[:prepack_label_id]
  end

  test 'pack dispensations require an exact label' do
    dispensation = Dispensation.new(dispensation_type: 'pack')
    dispensation.valid?

    assert_includes dispensation.errors[:prepack_label], "can't be blank"
  end

  test 'pack dispensations accept an exact label' do
    label = PrepackLabel.new(label_identifier: 'PK-TEST-1')
    dispensation = Dispensation.new(dispensation_type: 'pack', prepack_label: label)
    dispensation.valid?

    assert_same label, dispensation.prepack_label
    assert_empty dispensation.errors[:prepack_label]
    assert_empty dispensation.errors[:dispensation_type]
  end

  test 'bottle dispensations cannot reference a pack label' do
    dispensation = Dispensation.new(dispensation_type: 'bottle', prepack_label_id: 1)
    dispensation.valid?

    assert_includes dispensation.errors[:prepack_label_id], 'must be blank'
  end

  test 'unreversed dispensations do not require reversal metadata' do
    dispensation = Dispensation.new(dispensation_type: 'bottle')
    dispensation.valid?

    assert_empty dispensation.errors[:reversal_reason]
    assert_empty dispensation.errors[:reversed_by]
    assert_empty dispensation.errors[:reversed_at]
  end

  test 'partial reversal details require reason user and timestamp' do
    dispensation = Dispensation.new(dispensation_type: 'bottle', reversal_notes: 'Wrong pack selected')
    dispensation.valid?

    assert_includes dispensation.errors[:reversal_reason], "can't be blank"
    assert_includes dispensation.errors[:reversed_by], "can't be blank"
    assert_includes dispensation.errors[:reversed_at], "can't be blank"
  end

  test 'complete reversal metadata accepts optional notes' do
    dispensation = Dispensation.new(
      dispensation_type: 'bottle', reversal_reason: 'wrong_medication',
      reversed_by: User.new, reversed_at: Time.current
    )
    dispensation.valid?

    assert_empty dispensation.errors[:reversal_reason]
    assert_empty dispensation.errors[:reversed_by]
    assert_empty dispensation.errors[:reversed_at]
    assert_nil dispensation.reversal_notes
  end

  test 'recording reversal metadata preserves the original dispensation' do
    user = User.new(username: 'reversal_test', password: 'stored-password', salt: 'existing-salt')
    user.save!(validate: false)
    dispensation = Dispensation.create!(dispensation_type: 'bottle', quantity: 10)
    original_id = dispensation.id

    dispensation.update!(reversal_reason: 'wrong_medication', reversal_notes: 'Selected in error',
                         reversed_by: user, reversed_at: Time.current)

    original = Dispensation.find(original_id)
    assert_equal 10, original.quantity
    assert_equal 'wrong_medication', original.reversal_reason
    assert_equal 'Selected in error', original.reversal_notes
    assert_equal user.id, original.reversed_by_id
    assert_not_nil original.reversed_at
  end

  test 'reversal eligibility ends exactly 24 hours after dispensing' do
    travel_to(Time.current.change(usec: 0)) do
      dispensation = Dispensation.new(dispensation_type: 'bottle', dispensation_date: Time.current)
      assert dispensation.reversible?
      assert dispensation.reversal_window_open?(at: Time.current + 24.hours - 1.second)
      assert_not dispensation.reversal_window_open?(at: Time.current + 24.hours)
    end
  end
end
