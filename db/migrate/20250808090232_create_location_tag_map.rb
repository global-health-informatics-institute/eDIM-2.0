class CreateLocationTagMap < ActiveRecord::Migration
  def change
    create_table :location_tag_map, id: false do |t|
      t.integer :location_tag_id, null: false
      t.integer :location_id, null: false

      t.timestamps
    end

    # Composite primary key is not natively supported by ActiveRecord,
    add_index :location_tag_map, [:location_tag_id, :location_id], unique: true
  end
end