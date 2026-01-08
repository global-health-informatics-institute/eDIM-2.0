class BillingPatientIdentifier < BillingReadonlyRecord
  self.table_name = 'patient_identifier'
  
  belongs_to :patient, class_name: 'BillingPatient', foreign_key: 'patient_id', optional: true
end
