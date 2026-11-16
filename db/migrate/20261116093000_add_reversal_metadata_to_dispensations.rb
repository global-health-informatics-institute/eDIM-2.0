class AddReversalMetadataToDispensations < ActiveRecord::Migration[7.0]
  def change
    add_reference :dispensations, :prepack_label, foreign_key: true
    # Existing records cannot reliably be classified from their inventory reference.
    add_column :dispensations, :dispensation_type, :string, default: 'unknown', null: false
    add_column :dispensations, :reversal_reason, :string
    add_column :dispensations, :reversal_notes, :text
    add_reference :dispensations, :reversed_by,
                  foreign_key: { to_table: :users, primary_key: :user_id }
    add_column :dispensations, :reversed_at, :datetime
  end
end
