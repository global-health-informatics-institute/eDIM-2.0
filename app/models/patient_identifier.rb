class PatientIdentifier < ActiveRecord::Base
  establish_connection Registration
  self.table_name= "patient_identifier"

  belongs_to :type,-> { where "retired = 0" }, :class_name => "PatientIdentifierType", :foreign_key => :identifier_type
  belongs_to :patient, -> { where "voided = 0" }

  def self.identifier(patient_id, patient_identifier_type_id)
    patient_identifier = self.first.select("identifier").where("patient_id = ? and identifier_type = ?",patient_id, patient_identifier_type_id)

    return patient_identifier
  end

end
