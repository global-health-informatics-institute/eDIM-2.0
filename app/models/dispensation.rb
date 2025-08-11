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

      item = GeneralInventory.where("gn_identifier = ? AND voided = ?", dispensation.inventory_id, false).first

      if item.blank?
        return dispensation
      else
        prescription = dispensation.prescription

        item.current_quantity += dispensation.quantity
        item.save

        dispensation.voided = true
        dispensation.save

        prescription.amount_dispensed -= dispensation.quantity
        prescription.save
      end
    end
    return dispensation
  end

end
