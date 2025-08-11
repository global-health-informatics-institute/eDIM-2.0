class Prescription < ActiveRecord::Base
  belongs_to :patient, :foreign_key => :patient_id
  belongs_to :drug, :foreign_key => :drug_id

  def patient_name
    self.patient.full_name rescue ''
  end

  def drug_name
    #this method handles the need to access the drug name associated to the prescription
    self.drug.name.humanize.gsub(/\b('?[a-z])/) { $1.capitalize } rescue ""
  end

end