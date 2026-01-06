class AddGnIdentifierToPrepacks < ActiveRecord::Migration[7.0]
  def change
    add_column :prepacks, :gn_identifier, :string
    add_index :prepacks, :gn_identifier
  end
end