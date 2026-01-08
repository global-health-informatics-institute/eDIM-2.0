class BillingPersonAddress < BillingReadonlyRecord
  self.table_name = 'person_address'
  
  belongs_to :person, class_name: 'BillingPerson', foreign_key: 'person_id'
  
  scope :preferred, -> { where(preferred: 1) }
  
  def full_address
    [address1, address2, city_village, state_province, country].compact.reject(&:blank?).join(', ')
  end
end
