class AddDamageTypeToDamages < ActiveRecord::Migration[7.0]
  def change
    add_column :damages, :damage_type, :string, default: "pack", null: false
    add_index :damages, :damage_type
  end
end
