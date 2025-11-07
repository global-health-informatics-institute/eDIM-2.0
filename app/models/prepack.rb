class Prepack < ActiveRecord::Base
  belongs_to :bottle, class_name: 'GeneralInventory'
  belongs_to :drug
  belongs_to :prepacked_by, class_name: 'User'

  validates :quantity_per_pack, :num_packs, :total_quantity, presence: true
end
