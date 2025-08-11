class CreatePersonAddress < ActiveRecord::Migration
  def change
    create_table :person_address, id: false do |t|
      t.primary_key :person_address_id
      t.integer :person_id, null: false
      t.string :address1
      t.string :address2
      t.string :address3
      t.string :city_village
      t.string :state_province
      t.string :country
      t.string :postal_code
      t.boolean :preferred, default: false
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed

      t.timestamps
    end

    add_index :person_address, :person_id
  end
end