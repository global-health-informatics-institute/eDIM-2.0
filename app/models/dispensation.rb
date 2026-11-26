class Dispensation < ActiveRecord::Base
  belongs_to :patient,
             class_name: 'EdimPatient',
             foreign_key: :patient_id,
             optional: true

  belongs_to :prescription, foreign_key: :rx_id, optional: true
  belongs_to :general_inventory, foreign_key: :inventory_id, optional: true
  belongs_to :user, foreign_key: 'dispensed_by'
  belongs_to :location

  # Update departure time when dispensation is created
  after_create :update_patient_departure_time

  def drug_name
    prescription&.drug_name || general_inventory&.drug_name || "Unknown drug"
  end

  def dispensation_dir
    prescription&.directions.presence || "Dispensed without prescription"
  end

  def dispensed_by_name
    user&.display_name || 'Unknown'
  end

  def self.void(id)
    dispensation = Dispensation.find(id)

    Dispensation.transaction do
      if dispensation.inventory_id.present?
        item = GeneralInventory.find_by(
          gn_inventory_id: dispensation.inventory_id,
          voided: false
        )

        if item
          item.current_quantity += dispensation.quantity
          item.save!
        end
      end

      dispensation.update!(voided: true)

      if dispensation.prescription.present?
        prescription = dispensation.prescription
        prescription.amount_dispensed =
          prescription.amount_dispensed.to_i - dispensation.quantity.to_i
        prescription.save!
      end
    end

    dispensation
  end

  private

  def update_patient_departure_time
    return unless patient_id && dispensation_date

    # Find the most recent open visit for this patient on the dispensation date
    visit = EdimVisit.where(
      edim_patient_id: patient_id,
      visit_date: dispensation_date.to_date,
      departure_time: nil
    ).order(arrival_time: :desc).first

    if visit
      # Update departure time to dispensation time
      visit.update!(departure_time: dispensation_date)
    end
  end
end