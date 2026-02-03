class EdimVisit < ActiveRecord::Base
  belongs_to :edim_patient

  # Validations
  validates :arrival_time, presence: true
  validates :visit_date, presence: true
  validates :identifier, presence: true

  # Calculate visit duration in hours
  def duration_hours
    return nil unless departure_time
    
    duration_seconds = departure_time - arrival_time
    (duration_seconds / 1.hour).round(2)
  end

  # Check if patient stayed longer than specified hours
  def stayed_longer_than?(hours)
    duration_hours && duration_hours >= hours
  end

  # Scope for visits with departure time recorded
  scope :completed, -> { where.not(departure_time: nil) }
  
  # Scope for visits on a specific date
  scope :on_date, ->(date) { where(visit_date: date) }

  # Scope for visits by identifier
  scope :by_identifier, ->(identifier) { where(identifier: identifier) }

  # Mark departure
  def mark_departure!
    update!(departure_time: Time.current)
  end

  # Get patient name through association
  def patient_name
    edim_patient&.full_name || 'Unknown Patient'
  end

  # Check if visit is completed (has departure time)
  def completed?
    departure_time.present?
  end

  # Class methods for reporting
  def self.patients_stayed_longer_than(hours, date = Date.current)
    on_date(date).completed.select { |visit| visit.stayed_longer_than?(hours) }
  end

  def self.average_duration_hours(date = Date.current)
    visits = on_date(date).completed
    return 0 if visits.empty?
    
    total_hours = visits.sum(&:duration_hours)
    (total_hours / visits.count).round(2)
  end

  def self.total_visits_count(date = Date.current)
    on_date(date).count
  end

  def self.completed_visits_count(date = Date.current)
    on_date(date).completed.count
  end
end
