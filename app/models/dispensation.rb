class Dispensation < ActiveRecord::Base
  belongs_to :patient, :foreign_key => :patient_id
  belongs_to :prescription, :foreign_key => :rx_id
  belongs_to :general_inventory, :foreign_key => :inventory_id

  def drug_name
    #this method handles the need to access the drug name associated to the dispensation
    self.prescription.drug_name
  end

  def dispensation_dir
    self.prescription.directions
  end
  
  def self.void(id)
    dispensation = Dispensation.find(id)

    Dispensation.transaction do
      item = GeneralInventory.find_by(gn_inventory_id: dispensation.inventory_id, voided: false)

      if item.present?
        item.current_quantity += dispensation.quantity
        item.save!
      end

      dispensation.update!(voided: true)

      if dispensation.prescription.present?
        prescription = dispensation.prescription
        prescription.amount_dispensed -= dispensation.quantity
        prescription.save!
      end
    end

    dispensation
  end

end
