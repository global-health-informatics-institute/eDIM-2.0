class AddLocationIdToPrepacks < ActiveRecord::Migration[7.0]
  def change
    add_column :prepacks, :location_id, :integer
  end
end
