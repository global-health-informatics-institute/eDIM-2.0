class AddArrivalAndDepartureTimeToEdimPatients < ActiveRecord::Migration[5.2]
  def change
    add_column :edim_patients, :arrival_time, :datetime
    add_column :edim_patients, :departure_time, :datetime

    add_index :edim_patients, :arrival_time
    add_index :edim_patients, :departure_time
  end
end