<<<<<<< HEAD
class CreateLocationTagMap < ActiveRecord::Migration [7.0]
=======
class CreateLocationTagMap < ActiveRecord::Migration[7.0]
>>>>>>> 2d57a4e (clean up migration versions)
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