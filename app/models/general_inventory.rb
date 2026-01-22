class GeneralInventory < ActiveRecord::Base
  belongs_to :drug, foreign_key: :drug_id
  before_create :complete_record
  after_create  :reorder_gn_sequence_for_drug
  has_many :damages,
           foreign_key: :general_inventory_id,
           primary_key: :gn_inventory_id
  self.primary_key = 'gn_inventory_id'

  validates :expiration_date, :date_received, :received_quantity, :current_quantity, presence: true
  validates :received_quantity, :current_quantity, numericality: { only_integer: true, greater_than: -1 }
  validates_associated :drug

  include Misc

  def drug_name
    self.drug.name.humanize.gsub(/\b('?[a-z])/) { $1.capitalize } rescue ""
  end

  def drug_category
    self.drug.category.humanize.gsub(/\b('?[a-z])/) { $1.capitalize } rescue ""
  end

  def bottle_id
    self.gn_identifier
  end

  def self.void_item(bottle_id)
    item = GeneralInventory.find_by(gn_inventory_id: bottle_id)
    return false if item.blank?

    item.update(voided: true, void_reason: "Unspecified")
    item
  end

  def dose_form
    self.drug.dose_form
  end

  def bottle_damages
    damages.where(damage_type: 'bottle', gn_identifier: self.gn_identifier).sum(:quantity)
  end

  def expired?
    expiration_date.present? && expiration_date <= Date.current
  end

  private

  def complete_record
    self.current_quantity ||= self.received_quantity
    self.date_received    ||= Date.current
    self.created_by       ||= User.current.id

    existing_entries = GeneralInventory.where(drug_id: self.drug_id)
                                       .order(:expiration_date, :gn_inventory_id)

    if existing_entries.present?
      # Reuse the base gn_identifier of the first existing bottle
      self.gn_identifier = existing_entries.first.gn_identifier
    else
      # First time this drug is added → generate a new base identifier
      last_id = GeneralInventory.order(gn_inventory_id: :desc).pick(:gn_inventory_id).to_i rescue 0
      next_number = (last_id + 1).to_s.rjust(6, "0")
      check_digit = calculate_check_digit(next_number)
      self.gn_identifier = "G#{next_number}#{check_digit}"
    end
  end

  def reorder_gn_sequence_for_drug
    entries = GeneralInventory.where(drug_id: self.drug_id)
                              .order(:expiration_date, :gn_inventory_id)

    entries.each_with_index do |entry, index|
      entry.update_column(:gn_sequence, format('%04d', index + 1))
    end
  end
end