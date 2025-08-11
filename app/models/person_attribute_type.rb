class PersonAttributeType < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "person_attribute_type"
  self.primary_key = "person_attribute_type_id"

  has_many :person_attributes, -> {where "voided = false"}

end
