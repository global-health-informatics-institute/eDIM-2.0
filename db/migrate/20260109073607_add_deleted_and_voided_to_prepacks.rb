class AddDeletedAndVoidedToPrepacks < ActiveRecord::Migration[7.0]
  def change
    
    add_column :prepacks, :voided, :boolean, default: false, null: false
    add_column :prepacks, :deleted, :boolean, default: false, null: false
    
    add_index :prepacks, :voided
    add_index :prepacks, :deleted
  end
end
