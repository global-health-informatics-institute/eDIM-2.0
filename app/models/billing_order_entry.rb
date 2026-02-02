class BillingOrderEntry < BillingReadonlyRecord
  self.table_name = 'order_entries'
  
  # Associations
  belongs_to :patient, 
             class_name: 'BillingPatient', 
             foreign_key: 'patient_id',
             optional: true
             
  scope :for_patient, ->(patient_id) { where(patient_id: patient_id) }
  scope :for_date, ->(date) { where('DATE(order_date) = ?', date) }
  scope :recent_first, -> { order(order_date: :desc) }
end