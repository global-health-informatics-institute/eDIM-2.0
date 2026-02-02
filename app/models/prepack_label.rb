class PrepackLabel < ActiveRecord::Base
  belongs_to :prepack
  belongs_to :bottle, class_name: 'GeneralInventory', foreign_key: 'bottle_id'
  has_many :prepack_labels, foreign_key: :prepack_id
  validates :label_identifier, presence: true, uniqueness: true

  # Update departure time when prepack label is dispensed
  after_update :update_patient_departure_time, if: :saved_change_to_dispensed?

  private

  def update_patient_departure_time
    return unless dispensed? && patient_id && date_dispensed

    # Find the most recent visit for this patient on the dispensed date
    visit = EdimVisit.where(
      edim_patient_id: patient_id,
      visit_date: date_dispensed.to_date
    ).order(arrival_time: :desc).first

    if visit
      # Update departure time to dispensed time
      visit.update!(departure_time: date_dispensed)
    end
  end
end