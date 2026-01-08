class BillingReadonlyRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection :billing_readonly
end

class BillingLocation < BillingReadonlyRecord
  self.table_name = 'location'
end

class BillingPatient < BillingReadonlyRecord
  self.table_name = 'patient'
end

class BillingPerson < BillingReadonlyRecord
  self.table_name = 'person'
end
