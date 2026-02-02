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

    # Always try to get the most recent order entry for today first
    recent_order = BillingOrderEntry
      .for_patient(billing_patient.patient_id)
      .for_date(Date.current)
      .recent_first
      .first

    # Determine arrival time based on whether there's an order entry for today
    arrival_time = if recent_order
      # Patient has an order entry for today - use that as arrival time
      recent_order.order_date
    else
      # No order entry for today - use when they were originally created in OpenMRS
      billing_patient.date_created
    end

    # Always create a new visit record - no find_or_create, just create!
    EdimVisit.create!(
      edim_patient: patient,
      visit_date: Date.current,
      arrival_time: arrival_time
    )
  end
end