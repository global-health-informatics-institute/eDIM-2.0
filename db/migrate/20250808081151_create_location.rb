class CreateLocation < ActiveRecord::Migration
  def change
    create_table :location, id: false do |t|
      t.primary_key :location_id
      t.string :name, null: false
      t.string :description
      t.string :address1
      t.string :address2
      t.string :city_village
      t.string :state_province
      t.string :country
      t.string :postal_code
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed
      t.string :uuid
      t.string :neighborhood_cell

      t.timestamps
    end

    add_index :location, :name
  end
end