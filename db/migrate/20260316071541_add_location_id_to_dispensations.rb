class AddLocationIdToDispensations < ActiveRecord::Migration[7.0]
  def change
    add_column :dispensations, :location_id, :integer
  end
end
