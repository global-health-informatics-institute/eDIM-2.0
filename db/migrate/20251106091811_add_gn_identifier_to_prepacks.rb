class AddGnIdentifierToPrepacks < ActiveRecord::Migration[6.1]
  def change
    add_column :prepacks, :gn_identifier, :string
    add_index :prepacks, :gn_identifier
  end
end