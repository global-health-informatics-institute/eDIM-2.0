class AddItemCodeToDrugs < ActiveRecord::Migration
  def change
    add_column :drugs, :item_code, :string
  end
end
