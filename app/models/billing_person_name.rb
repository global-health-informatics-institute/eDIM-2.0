class BillingPersonName < BillingReadonlyRecord
  self.table_name = 'person_name'
  
  belongs_to :person, class_name: 'BillingPerson', foreign_key: 'person_id'
  
  def full_name
    [given_name, middle_name, family_name, family_name2].compact
      .reject(&:blank?).join(' ').presence || 'Unknown'
  end
end
