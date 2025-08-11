class GeneralInventory < ActiveRecord::Base
  belongs_to :drug, :foreign_key => :drug_id
  before_create :complete_record

  validates :expiration_date, :presence => true
  validates :date_received, :presence => true
  validates :received_quantity, :presence => true
  validates :current_quantity, :presence => true
  validates :received_quantity, :numericality => { :only_integer => true }
  validates :received_quantity, :numericality => { :greater_than => -1 }
  validates :current_quantity, :numericality => { :only_integer => true }
  validates :current_quantity, :numericality => { :greater_than => -1 }
  validates_associated :drug

  include Misc

  def drug_name
    #this method handles the need to access the drug name associated to the inventory entry
    self.drug.name.humanize.gsub(/\b('?[a-z])/) { $1.capitalize } rescue ""
  end

  def drug_category
    self.drug.category.humanize.gsub(/\b('?[a-z])/) { $1.capitalize } rescue ""
  end

  def bottle_id
    return self.gn_identifier
  end

  def self.void_item(bottle_id)
    item = GeneralInventory.find(bottle_id)
    unless item.blank?
      item.voided = true
      item.void_reason = "Unspecified"
      item.save
      return item
    end

    return false
  end

  def dose_form
    self.drug.dose_form
  end
  private

  def complete_record
    self.current_quantity = self.received_quantity
    self.date_received = Date.current
    self.created_by = User.current.id
    unless !self.gn_identifier.blank?
      last_id = GeneralInventory.order(gn_inventory_id: :desc).first.id rescue "0"
      next_number = (last_id.to_i+1).to_s.rjust(6,"0")
      check_digit = calculate_check_digit(next_number)
      self.gn_identifier = "G#{next_number}#{check_digit}"
    end
  end
end
