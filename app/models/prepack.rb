class Prepack < ActiveRecord::Base
  belongs_to :bottle, class_name: 'GeneralInventory'
  belongs_to :drug
  belongs_to :prepacked_by, class_name: 'User'
  belongs_to :location, optional: true

  has_many :prepack_labels, dependent: :destroy

  # -----------------------
  # VALIDATIONS
  # -----------------------
  validates :drug_id, :location_id, :quantity_per_pack, :num_packs, presence: true
  validates :pack_identifier, uniqueness: true, allow_nil: true

  validate :cannot_reduce_below_dispensed

  # -----------------------
  # CALLBACKS
  # -----------------------
  before_validation :calculate_total_quantity
  #before_save :generate_directions
  after_initialize :set_default_status, if: :new_record?

  # -----------------------
  # METHODS
  # -----------------------
  def times
    super || []
  end

  private

  def set_default_status
    self.status ||= 'available'
  end

  # Automatically calculate total quantity
  def calculate_total_quantity
    self.total_quantity = quantity_per_pack.to_i * num_packs.to_i
  end

  # Prevent reducing num_packs below already dispensed packs
  def cannot_reduce_below_dispensed
    return unless persisted?

    dispensed = prepack_labels.where(dispensed: true, deleted: false, voided: false).count
    if num_packs.to_i < dispensed
      errors.add(:num_packs, "cannot be less than already dispensed packs (#{dispensed})")
    end
  end

  #def generate_directions
    #return unless dose.present? && frequency.present? && administration.present?

    #freq_words = { 'OD' => 'Once', 'BD' => 'Two', 'TDS' => 'Three', 'QID' => 'Four' }
    #route_words = { 'oral' => 'Take', 'topical' => 'Apply', 'injection' => 'Inject', 'respiratory' => 'Inhale' }

    #freq_word  = freq_words[frequency] || 'Two'
    #route_word = route_words[administration] || 'Take'

    #self.directions = 
    #"#{route_word} #{dose} #{freq_word} Times A Day"
  #end
end
