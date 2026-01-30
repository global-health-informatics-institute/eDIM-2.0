class EdimPatient < ActiveRecord::Base
  self.primary_key = :patient_id

  # Prevent accidental deletes
  def readonly?
    false
  end

  # Convenience helpers
  def name
    full_name.presence || [given_name, family_name].compact.join(' ')
  end
end
