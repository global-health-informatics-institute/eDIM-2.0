class Prepack < ActiveRecord::Base
  belongs_to :bottle, class_name: 'GeneralInventory'
  belongs_to :drug
  belongs_to :prepacked_by, class_name: 'User'

  # Ensure essential fields are present
  validates :quantity_per_pack, :num_packs, :total_quantity, presence: true

  # Validate uniqueness of pack_identifier if present
  validates :pack_identifier, uniqueness: true, allow_nil: true

  # Set default status to 'available'
  after_initialize :set_default_status, if: :new_record?

  private

  def set_default_status
    self.status ||= 'available'
  end
end