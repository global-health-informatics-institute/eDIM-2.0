class CreatePerson < ActiveRecord::Migration
  def change
    create_table :person, id: false do |t|
      t.primary_key :person_id
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed
      t.boolean :dead, default: false
      t.date :birthdate
      t.boolean :birthdate_estimated, default: false
      t.date :death_date
      t.integer :cause_of_death
      t.integer :gender # optional if using enum/lookup; otherwise use string
      t.string :gender_string
      t.integer :death_reason
      t.integer :death_place
      t.string :death_place_other

      t.timestamps
    end
  end
end