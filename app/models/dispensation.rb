class Dispensation < ActiveRecord::Base
  belongs_to :patient, foreign_key: :patient_id
  belongs_to :prescription, foreign_key: :rx_id, optional: true
  belongs_to :general_inventory, foreign_key: :inventory_id, optional: true
  belongs_to :user, foreign_key: 'dispensed_by'

  def drug_name
    prescription&.drug_name || general_inventory&.drug_name || "Unknown drug"
  end

  # Directions if prescription exists, otherwise fallback text
  def dispensation_dir
    prescription&.directions.presence || "Dispensed without prescription"
  end

  # Voiding a dispensation should restore inventory and adjust prescription
  def self.void(id)
    dispensation = Dispensation.find(id)

    Dispensation.transaction do
      if dispensation.inventory_id.present?
        item = GeneralInventory.find_by(gn_inventory_id: dispensation.inventory_id, voided: false)
        if item
          item.current_quantity += dispensation.quantity
          item.save!
        end
      end

      dispensation.update!(voided: true)

      if dispensation.prescription.present?
        prescription = dispensation.prescription
        prescription.amount_dispensed = prescription.amount_dispensed.to_i - dispensation.quantity.to_i
        prescription.save!
      end
    end

    dispensation
  end
end