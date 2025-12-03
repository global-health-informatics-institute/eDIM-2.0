class CreateDamages < ActiveRecord::Migration[7.0]
  def change
    create_table :damages do |t|
      t.integer :general_inventory_id, null: false
      t.integer :quantity, null: false, default: 0
      t.string :reason
      t.integer :user_id
      t.timestamps
    end

    add_index :damages, :general_inventory_id
  end
end
