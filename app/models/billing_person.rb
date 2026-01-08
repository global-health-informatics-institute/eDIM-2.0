class BillingPerson < BillingReadonlyRecord
  self.table_name = 'person'
  
  has_many :person_names, class_name: 'BillingPersonName', foreign_key: 'person_id'
  has_one :preferred_name, -> { where(preferred: 1) }, class_name: 'BillingPersonName', foreign_key: 'person_id'
  has_many :person_addresses, class_name: 'BillingPersonAddress', foreign_key: 'person_id'
  
  def full_name
    preferred_name&.full_name || person_names.first&.full_name || 'Unknown'
  end
  
  def current_address
    person_addresses.where(preferred: 1).first&.full_address || person_addresses.first&.full_address || 'N/A'
  end
end
