class CreatePatientIdentifierType < ActiveRecord::Migration
  def change
    create_table :patient_identifier_type, id: false do |t|
      t.primary_key :patient_identifier_type_id
      t.string :name, null: false
      t.text :description
      t.boolean :retired, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :retired_by
      t.datetime :date_retired
      t.string :retire_reason

      t.timestamps
    end
  end
end