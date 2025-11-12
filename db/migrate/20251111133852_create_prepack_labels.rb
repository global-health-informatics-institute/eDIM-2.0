class CreatePrepackLabels < ActiveRecord::Migration[7.0]
  def change
    create_table :prepack_labels do |t|
      t.bigint :prepack_id, null: false         # matches prepacks.id
      t.integer :bottle_id, null: false         # matches general_inventories.gn_inventory_id
      t.string :label_identifier, null: false
      t.boolean :dispensed, default: false
      t.timestamps
    end

    # Foreign keys
    add_foreign_key :prepack_labels, :prepacks
    add_foreign_key :prepack_labels, :general_inventories, column: :bottle_id, primary_key: :gn_inventory_id

    # Indexes
    add_index :prepack_labels, :prepack_id
    add_index :prepack_labels, :label_identifier, unique: true
  end
end