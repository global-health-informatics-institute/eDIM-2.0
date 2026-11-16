class DispensationReversal
  class Error < StandardError; end
  class AlreadyReversed < Error; end

  def self.call(dispensation_id:, reason:, user:, location_id:, notes: nil)
    reason = reason.to_s.strip
    notes = notes.to_s.strip.presence
    raise Error, 'Select a valid reason for reversal.' unless Dispensation::REVERSAL_REASONS.key?(reason)
    raise Error, 'Please specify the reason for reversal.' if reason == 'other' && notes.blank?
    raise Error, 'Please log in again.' if user&.id.blank? || user.retired?
    raise Error, 'Please select a location first.' if location_id.blank?

    original = Dispensation.find(dispensation_id)
    raise Error, 'This historical dispensation needs reconciliation before reversal.' if original.dispensation_type_unknown?

    Dispensation.transaction do
      # Match the dispensing lock order: label, batch, bottle, then the records being changed.
      if original.dispensation_type_pack?
        label = PrepackLabel.lock.find(original.prepack_label_id)
        prepack = Prepack.lock.find(label.prepack_id)
        bottle = GeneralInventory.lock.find(prepack.bottle_id)
      else
        raise Error, 'The original bottle reference needs reconciliation.' unless original.inventory_id.to_s.match?(/\A[1-9]\d*\z/)
        bottle = GeneralInventory.lock.find(original.inventory_id)
      end

      dispensation = Dispensation.lock.find(original.id)
      raise AlreadyReversed, 'This dispensation has already been reversed or voided.' if
        dispensation.voided? || dispensation.reversed_at.present?
      blocked_reason = dispensation.reversal_blocked_reason
      raise Error, blocked_reason if blocked_reason
      raise Error, 'The dispensation source changed. Refresh the patient history.' unless
        dispensation.dispensation_type == original.dispensation_type &&
        dispensation.prepack_label_id == original.prepack_label_id &&
        dispensation.inventory_id == original.inventory_id
      raise Error, 'This dispensation belongs to another location.' unless bottle.location_id.to_s == location_id.to_s
      raise Error, 'The source bottle is voided and needs reconciliation.' if bottle.voided?
      raise Error, 'This dispensation has an invalid quantity.' unless dispensation.quantity.to_i.positive?

      prescription = Prescription.lock.find(dispensation.rx_id) if dispensation.rx_id.present?
      # A request may have waited for the prescription lock across the deadline.
      blocked_reason = dispensation.reversal_blocked_reason
      raise Error, blocked_reason if blocked_reason
      if prescription && (prescription.patient_id != dispensation.patient_id ||
                           prescription.drug_id != bottle.drug_id ||
                           prescription.amount_dispensed.to_i < dispensation.quantity)
        raise Error, 'The prescription totals or references need reconciliation.'
      end

      if label
        raise Error, 'This pack is no longer available for reversal.' if
          label.voided? || label.deleted? || prepack.voided? || prepack.deleted?
        raise Error, 'This pack belongs to another location.' unless prepack.location_id.to_s == location_id.to_s
        raise Error, 'The pack assignment needs reconciliation.' unless
          label.dispensed? && label.patient_id.to_s == dispensation.patient_id.to_s &&
          label.bottle_id == bottle.id && dispensation.inventory_id == bottle.id.to_s &&
          prepack.drug_id == bottle.drug_id && prepack.quantity_per_pack == dispensation.quantity
        raise Error, 'This pack has another active dispensation.' if
          label.dispensations.where(voided: false).where.not(dispensation_id: dispensation.id).exists?

        label.update!(dispensed: false, patient_id: nil, dispensed_by: nil, date_dispensed: nil)
        prepack.update!(status: 'available')
      else
        bottle.update!(current_quantity: bottle.current_quantity + dispensation.quantity)
      end

      prescription.update!(amount_dispensed: prescription.amount_dispensed - dispensation.quantity) if prescription
      dispensation.update!(voided: true, reversal_reason: reason, reversal_notes: notes,
                           reversed_by: user, reversed_at: Time.current)
      dispensation
    end
  end
end
