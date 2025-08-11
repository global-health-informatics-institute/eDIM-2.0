class Role < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "role"
  self.primary_key = "role"

  has_many :user_roles, :foreign_key => :role # no default scope
end
