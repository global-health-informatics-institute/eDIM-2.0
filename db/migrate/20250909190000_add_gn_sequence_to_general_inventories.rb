class AddGnSequenceToGeneralInventories < ActiveRecord::Migration[6.1]
  def change
    add_column :general_inventories, :gn_sequence, :string, limit: 4
  end
end