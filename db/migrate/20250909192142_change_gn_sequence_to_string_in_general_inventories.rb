class ChangeGnSequenceToStringInGeneralInventories < ActiveRecord::Migration[7.0]
  def change
    change_column :general_inventories, :gn_sequence, :string
  end
end