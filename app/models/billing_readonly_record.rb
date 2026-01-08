class BillingReadonlyRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection :billing_development

  def readonly?
    true
  end
end
