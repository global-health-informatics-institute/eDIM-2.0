class PrepackLabel < ActiveRecord::Base
  belongs_to :prepack
  belongs_to :bottle, class_name: 'GeneralInventory', foreign_key: 'bottle_id'

  validates :label_identifier, presence: true, uniqueness: true
end