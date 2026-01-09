class BillingPatient < BillingReadonlyRecord
  self.table_name = 'patient'
  
  belongs_to :person, 
             class_name: 'BillingPerson', 
             foreign_key: 'patient_id',
             primary_key: 'person_id',
             optional: true
  
  has_many :patient_identifiers, 
           class_name: 'BillingPatientIdentifier',
           foreign_key: 'patient_id'
           
  delegate :gender, :birthdate, to: :person, prefix: true, allow_nil: true
  
  def sex
    person_gender || 'Unknown'
  end
  
  def full_name
    person&.full_name || 'Unknown Patient'
  end
  
  def age
    return 'Unknown' unless person_birthdate
    age = Date.current.year - person_birthdate.year
    age -= 1 if Date.current < person_birthdate + age.years
    age.to_s
  end
  

  def formatted_pnid

    national_id = patient_identifiers.where(identifier_type: 3).first&.identifier 
    national_id.presence || 'N/A'
  end
  

  def current_address
    person&.current_address || 'N/A'
  end
end
