class CreateGeneralInventories < ActiveRecord::Migration
  def change
    create_table :general_inventories, :primary_key => :gn_inventory_id do |t|
      t.integer :drug_id
      t.string :gn_identifier
      t.date :expiration_date
      t.date :date_received
      t.integer :received_quantity, :default => 0
      t.integer :current_quantity, :default => 0
      t.integer :location_id, null: false
      t.integer :created_by
      t.boolean :voided, :default => false
      t.string :void_reason
      t.integer :voided_by
      t.timestamps null: false
    end

    add_index :general_inventories, :gn_identifier
  end
end
