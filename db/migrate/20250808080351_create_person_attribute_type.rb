class CreatePersonAttributeType < ActiveRecord::Migration
  def change
    create_table :person_attribute_type, id: false do |t|
      t.primary_key :person_attribute_type_id
      t.string :name, null: false
      t.text :description
      t.boolean :retired, default: false
      t.integer :retired_by
      t.datetime :date_retired
      t.string :retire_reason
      t.integer :creator
      t.datetime :date_created

      t.timestamps
    end
  end
end