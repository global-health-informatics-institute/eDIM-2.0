class AddDetailsToDamages < ActiveRecord::Migration[7.0]
  def change
    add_column :damages, :reported_by, :integer
    add_column :damages, :location_id, :integer
    add_column :damages, :damage_date, :datetime
  end
end
