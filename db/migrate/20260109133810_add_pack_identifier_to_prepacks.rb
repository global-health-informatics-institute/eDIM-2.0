class AddPackIdentifierToPrepacks < ActiveRecord::Migration[7.0]
  def change
    add_column :prepacks, :pack_identifier, :string
  end
end
