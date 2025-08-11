class CreatePersonAttribute < ActiveRecord::Migration
  def change
    create_table :person_attribute, id: false do |t|
      t.primary_key :person_attribute_id
      t.integer :person_id, null: false
      t.integer :person_attribute_type_id, null: false
      t.text :value
      t.integer :creator
      t.datetime :date_created
      t.boolean :voided, default: false
      t.integer :voided_by
      t.datetime :date_voided
      t.string :void_reason

      t.timestamps
    end

    add_index :person_attribute, :person_id
    add_index :person_attribute, :person_attribute_type_id
  end
end