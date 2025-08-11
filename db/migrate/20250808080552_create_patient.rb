class CreatePatient < ActiveRecord::Migration
  def change
    create_table :patient do |t|
      t.integer :person_id, null: false
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed
      t.boolean :dead, default: false
      t.datetime :death_date
      t.integer :cause_of_death
      t.boolean :patient_id_card_printed, default: false

      t.timestamps
    end

    add_index :patient, :person_id
  end
end
