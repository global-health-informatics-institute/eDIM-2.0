class CreateEdimVisits < ActiveRecord::Migration[7.0]
  def change
    create_table :edim_visits do |t|
      t.integer :edim_patient_id, null: false
      t.datetime :arrival_time, null: false
      t.datetime :departure_time
      t.date :visit_date, null: false
      t.timestamps
    end

    # Add foreign key referencing the correct column type
    add_foreign_key :edim_visits, :edim_patients, column: :edim_patient_id, primary_key: :patient_id
    add_index :edim_visits, [:edim_patient_id, :visit_date], unique: true
  end
end