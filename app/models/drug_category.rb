class DrugCategory < ActiveRecord::Base
  has_many :drugs
end
