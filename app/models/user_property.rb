class UserProperty < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "user_property"
  self.primary_keys = :user_id, :property

  belongs_to :user, -> { where(voided: [false, nil]) }, foreign_key: :user_id
end
