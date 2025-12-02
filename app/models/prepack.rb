class Prepack < ActiveRecord::Base
  belongs_to :bottle, class_name: 'GeneralInventory'
  belongs_to :drug
  belongs_to :prepacked_by, class_name: 'User'
  belongs_to :location, optional: true
  validates :drug_id, :location_id, :quantity_per_pack, :num_packs, :total_quantity, presence: true

  #has_many :prepack_labels, foreign_key: :prepack_id
  has_many :prepack_labels, dependent: :destroy

  validates :quantity_per_pack, :num_packs, :total_quantity, presence: true

  validates :pack_identifier, uniqueness: true, allow_nil: true

  after_initialize :set_default_status, if: :new_record?

  private

  def set_default_status
    self.status ||= 'available'
  end
end