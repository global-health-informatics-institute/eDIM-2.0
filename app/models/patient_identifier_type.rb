class PatientIdentifierType < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "patient_identifier_type"
  self.primary_key = "patient_identifier_type_id"
end
