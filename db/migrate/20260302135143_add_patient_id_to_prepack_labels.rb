class AddPatientIdToPrepackLabels < ActiveRecord::Migration[7.0]
  def change
    add_column :prepack_labels, :patient_id, :string
  end
end
