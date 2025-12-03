class AddGnIdentifierToDamages < ActiveRecord::Migration[7.0]
  def change
    add_column :damages, :gn_identifier, :string
    add_index :damages, :gn_identifier
  end
end