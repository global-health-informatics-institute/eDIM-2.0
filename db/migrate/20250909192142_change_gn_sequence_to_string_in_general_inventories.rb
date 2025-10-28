class ChangeGnSequenceToStringInGeneralInventories < ActiveRecord::Migration[6.1]
  def change
    change_column :general_inventories, :gn_sequence, :string
  end
end