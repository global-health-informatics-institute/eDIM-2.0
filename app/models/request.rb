class Request < ActiveRecord::Base
  belongs_to :drug
  belongs_to :location, optional: true
  belongs_to :fulfilled_by_user, class_name: "User", foreign_key: :fulfilled_by, optional: true

  validates :drug_id, :location_id, :quantity, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end
