class AddItemCodeToDrugs < ActiveRecord::Migration[7.0]
  def change
    add_column :drugs, :item_code, :string
  end
end
