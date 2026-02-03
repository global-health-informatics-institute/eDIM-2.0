class AddIdentifierToEdimVisits < ActiveRecord::Migration[7.0]
  def change
    add_column :edim_visits, :identifier, :string, limit: 50
    
    # Add index for better performance
    add_index :edim_visits, :identifier
    
    # Populate identifier from edim_patients for existing records
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE edim_visits 
          SET identifier = (
            SELECT identifier 
            FROM edim_patients 
            WHERE edim_patients.patient_id = edim_visits.edim_patient_id
          )
          WHERE identifier IS NULL
        SQL
      end
    end
  end
end
