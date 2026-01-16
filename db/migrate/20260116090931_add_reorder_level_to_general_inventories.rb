class AddReorderLevelToGeneralInventories < ActiveRecord::Migration[7.0]
  def change
    add_column :general_inventories, :reorder_level, :integer, default: 10, null: false
  end
end
