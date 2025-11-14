class PrepackLabel < ActiveRecord::Base
  belongs_to :prepack
  belongs_to :bottle, class_name: 'GeneralInventory', foreign_key: 'bottle_id'
  has_many :prepack_labels, foreign_key: :prepack_id
  validates :label_identifier, presence: true, uniqueness: true
end