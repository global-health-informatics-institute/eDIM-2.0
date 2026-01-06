class CreateLocationTag < ActiveRecord::Migration[7.0]
  def change
    create_table :location_tag, id: false do |t|
      t.primary_key :location_tag_id
      t.string :name, null: false
      t.text :description
      t.boolean :retired, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :retired_by
      t.datetime :date_retired
      t.string :retire_reason
      t.string :uuid

      t.timestamps
    end

    add_index :location_tag, :name
  end
end