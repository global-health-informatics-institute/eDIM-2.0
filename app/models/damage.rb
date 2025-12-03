class Damage < ActiveRecord::Base
  belongs_to :general_inventory
  belongs_to :user, optional: true
end