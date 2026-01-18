class EdimPatientCache
  def self.upsert_from_billing!(billing_patient, scanned_identifier)
    person = billing_patient.person
    return unless person

    # Find existing patient or initialize a new one
    patient = EdimPatient.find_or_initialize_by(patient_id: billing_patient.patient_id)

    # Assign attributes from the billing patient
    patient.assign_attributes(
      given_name:  person.given_name || 'Unknown',
      family_name: person.family_name || 'Unknown',
      full_name:   billing_patient.full_name || 'Unknown Patient',
      gender:      billing_patient.sex,
      birthdate:   person.birthdate,
      identifier:  scanned_identifier
    )

    # Save the record
    patient.save!
  end
end
