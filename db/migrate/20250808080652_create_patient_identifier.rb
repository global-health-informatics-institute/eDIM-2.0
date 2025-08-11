class CreatePatientIdentifier < ActiveRecord::Migration
  def change
    create_table :patient_identifier do |t|
      t.integer :patient_id, null: false
      t.integer :identifier_type, null: false
      t.string :identifier, null: false
      t.boolean :preferred, default: false
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed

      t.timestamps
    end

    add_index :patient_identifier, :patient_id
    add_index :patient_identifier, :identifier_type
    add_index :patient_identifier, [:patient_id, :identifier_type], unique: true
  end
end