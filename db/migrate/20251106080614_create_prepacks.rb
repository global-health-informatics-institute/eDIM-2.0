class CreatePrepacks < ActiveRecord::Migration[7.0]
  def change
    create_table :prepacks do |t|
      t.integer :bottle_id, null: false
      t.integer :drug_id, null: false

      t.integer :quantity_per_pack, null: false
      t.integer :num_packs, null: false
      t.integer :total_quantity, null: false

      t.string :directions
      t.integer :prepacked_by_id, null: false  # User who prepacked

      t.string :status, default: 'created', null: false # created / printed / used

      t.timestamps
    end

    add_index :prepacks, :status

    # Foreign keys
    add_foreign_key :prepacks, :general_inventories, column: :bottle_id, primary_key: :gn_inventory_id
    add_foreign_key :prepacks, :drugs, column: :drug_id, primary_key: :drug_id
    add_foreign_key :prepacks, :users, column: :prepacked_by_id, primary_key: :user_id
  end
end