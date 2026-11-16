class PackDispensation
  class Error < StandardError; end

  class ExpiredPack < Error
    attr_reader :expiration_date

    def initialize(expiration_date)
      @expiration_date = expiration_date
      super('This pack has expired and cannot be dispensed.')
    end
  end

  def self.call(label_identifier:, patient_id:, user:, location_id:)
    raise Error, 'Location is not set. Please select a location first.' if location_id.blank?
    raise Error, 'Patient context missing. Please scan the patient first.' unless
      patient_id.present? && EdimPatient.exists?(patient_id: patient_id)
    raise Error, 'Please log in again.' if user&.id.blank?

    PrepackLabel.transaction do
      label = PrepackLabel.lock.find_by(label_identifier: label_identifier.to_s.strip)
      raise Error, 'This prepack has already been dispensed or is invalid' if
        label.nil? || label.dispensed? || label.voided? || label.deleted?
      prepack = Prepack.lock.find(label.prepack_id)
      raise Error, 'This prepack batch is no longer available' if prepack.voided? || prepack.deleted?
      raise Error, 'This pack already has an active dispensation' if
        label.dispensations.where(voided: false).exists?

      bottle = GeneralInventory.lock.find(prepack.bottle_id)
      raise Error, 'This pack is not available in the selected location' unless
        prepack.location_id.to_s == location_id.to_s && bottle.location_id.to_s == location_id.to_s
      raise Error, 'The source bottle is no longer available' if bottle.voided?
      raise Error, 'This pack has an invalid inventory reference' unless
        label.bottle_id == bottle.id && prepack.drug_id == bottle.drug_id
      raise ExpiredPack, bottle.expiration_date if bottle.expired?
      raise Error, 'This pack has an invalid quantity' unless prepack.quantity_per_pack.to_i.positive?

      # Dispensation timestamps are stored at second precision in the legacy schema.
      now = Time.current.change(usec: 0)
      times = prepack.times
      times = JSON.parse(times) if times.is_a?(String)
      prescription = Prescription.create!(
        patient_id: patient_id, drug_id: prepack.drug_id,
        date_prescribed: now, quantity: prepack.quantity_per_pack,
        amount_dispensed: prepack.quantity_per_pack,
        directions: prepack.directions.presence || 'Take as directed',
        times: Array(times).to_json, provider_id: user.id
      )

      # Loose stock was deducted when this pack was prepared.
      dispensation = Dispensation.create!(
        dispensation_type: 'pack', prepack_label: label,
        rx_id: prescription.id, inventory_id: bottle.id,
        patient_id: patient_id, quantity: prepack.quantity_per_pack,
        dispensation_date: now, dispensed_by: user.id
      )
      label.update!(dispensed: true, patient_id: patient_id,
                    dispensed_by: user.id, date_dispensed: now)

      remaining = prepack.prepack_labels.where(dispensed: false, voided: false, deleted: false).exists?
      prepack.update!(status: remaining ? 'available' : 'dispensed')
      dispensation
    end
  rescue ActiveRecord::RecordNotFound
    raise Error, 'The prepack or its source bottle was not found'
  rescue JSON::ParserError
    raise Error, 'This pack has invalid dosing times'
  end
end
