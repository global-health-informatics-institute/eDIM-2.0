class RemoveUniqueIndexFromEdimVisits < ActiveRecord::Migration[7.0]
  def change
    # Remove the foreign key constraint first
    remove_foreign_key :edim_visits, :edim_patients
    
    # Remove the unique constraint
    remove_index :edim_visits, [:edim_patient_id, :visit_date]
    
    # Add a non-unique index for performance
    add_index :edim_visits, [:edim_patient_id, :visit_date]
    
    # Re-add the foreign key constraint
    add_foreign_key :edim_visits, :edim_patients, column: :edim_patient_id, primary_key: :patient_id
  end
end
