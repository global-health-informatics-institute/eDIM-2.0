class EdimPatientCache
  def self.upsert_from_billing!(billing_patient, scanned_identifier)
    person = billing_patient.person
    return unless person

    patient = EdimPatient.find_or_create_by!(
      patient_id: billing_patient.patient_id
    ) do |p|
      p.given_name  = person.given_name || 'Unknown'
      p.family_name = person.family_name || 'Unknown'
      p.full_name   = billing_patient.full_name || 'Unknown Patient'
      p.gender      = billing_patient.sex
      p.birthdate   = person.birthdate
      p.identifier  = scanned_identifier
    end

    # One Visit per day
    EdimVisit.find_or_create_by!(
      edim_patient: patient,
      visit_date: Date.current
    ) do |visit|
      visit.arrival_time = Time.current
    end
  end
end