class RemoveArrivalDepartureTimeFromEdimPatients < ActiveRecord::Migration[7.0]
  def change
    remove_column :edim_patients, :arrival_time, :datetime
    remove_column :edim_patients, :departure_time, :datetime
  end
end
