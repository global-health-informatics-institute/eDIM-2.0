class Dispensation < ActiveRecord::Base
  REVERSAL_WINDOW = 24.hours
  REVERSAL_REASONS = {
    'wrong_medication' => 'Wrong medication',
    'wrong_pack' => 'Wrong pack',
    'wrong_patient' => 'Wrong patient',
    'duplicate' => 'Duplicate dispensing',
    'other' => 'Other'
  }.freeze
  belongs_to :patient,
             class_name: 'EdimPatient',
             foreign_key: :patient_id,
             optional: true

  belongs_to :prescription, foreign_key: :rx_id, optional: true
  belongs_to :general_inventory, foreign_key: :inventory_id, optional: true
  belongs_to :user, foreign_key: 'dispensed_by'
  belongs_to :location
  belongs_to :prepack_label, optional: true
  belongs_to :reversed_by, class_name: 'User', optional: true

  enum dispensation_type: { unknown: 'unknown', pack: 'pack', bottle: 'bottle' },
       _prefix: true

  validates :dispensation_type, inclusion: { in: ['pack', 'bottle'] }, on: :create
  validates :prepack_label, presence: true, if: :dispensation_type_pack?
  validates :prepack_label_id, absence: true, unless: :dispensation_type_pack?
  validates :reversal_reason, :reversed_by, :reversed_at,
            presence: true, if: :reversal_details_present?

  # Update departure time when dispensation is created
  after_create :update_patient_departure_time

  def drug_name
    prescription&.drug_name || general_inventory&.drug_name || "Unknown drug"
  end

  def dispensation_dir
    prescription&.directions.presence || "Dispensed without prescription"
  end

  def dispensed_by_name
    user&.display_name || 'Unknown'
  end

  def reversible?
    reversal_blocked_reason.nil?
  end

  def reversal_deadline
    dispensation_date + REVERSAL_WINDOW if dispensation_date
  end

  def reversal_window_open?(at: Time.current)
    dispensation_date.present? && dispensation_date <= at && at < reversal_deadline
  end

  def reversal_blocked_reason
    return 'This dispensation has already been reversed or voided.' if voided? || reversed_at.present?
    return 'Reversal requires reconciliation: identify the original pack or bottle.' if dispensation_type_unknown?
    return 'The dispensation time needs reconciliation before reversal.' if dispensation_date.nil? || dispensation_date > Time.current
    return 'The 24-hour reversal window has expired.' unless reversal_window_open?
  end

  def self.void(id, reason:, user:, location_id:, notes: nil)
    DispensationReversal.call(dispensation_id: id, reason: reason, notes: notes,
                             user: user, location_id: location_id)
  end

  private

  def reversal_details_present?
    [reversal_reason, reversal_notes, reversed_by_id, reversed_at].any?(&:present?)
  end

  def update_patient_departure_time
    return unless patient_id && dispensation_date

    # Find the most recent visit for this patient on the dispensation date
    visit = EdimVisit.where(
      edim_patient_id: patient_id,
      visit_date: dispensation_date.to_date
    ).order(arrival_time: :desc).first

    if visit
      # Update departure time to dispensation time
      visit.update!(departure_time: dispensation_date)
    end
  end
end