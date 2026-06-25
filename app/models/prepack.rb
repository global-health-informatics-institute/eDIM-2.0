class Prepack < ActiveRecord::Base
  belongs_to :bottle, class_name: 'GeneralInventory'
  belongs_to :drug
  belongs_to :prepacked_by, class_name: 'User'
  belongs_to :location, optional: true
  validates :drug_id, :location_id, :quantity_per_pack, :num_packs, :total_quantity, presence: true

  def times
    super || []
  end

  #has_many :prepack_labels, foreign_key: :prepack_id
  has_many :prepack_labels, dependent: :destroy

  validates :quantity_per_pack, :num_packs, :total_quantity, presence: true

  validates :pack_identifier, uniqueness: true, allow_nil: true

  after_initialize :set_default_status, if: :new_record?

  def pack_status
    labels = prepack_labels.where(deleted: false)
    total_packs = labels.count
    return status if total_packs.zero?

    damaged_packs = labels.where(voided: true).count
    remaining_packs = labels.where(voided: false).where(dispensed: [false, nil]).count

    if damaged_packs == total_packs
      'damaged'
    elsif remaining_packs.zero?
      'dispensed'
    else
      'active'
    end
  end

  def sync_pack_status!
    remaining_packs = prepack_labels
                      .where(deleted: false, voided: false)
                      .where(dispensed: [false, nil])
                      .count

    update!(
      current_num_packs: remaining_packs,
      status: pack_status
    )
  end

  private

  def set_default_status
    self.status ||= 'available'
  end
end
