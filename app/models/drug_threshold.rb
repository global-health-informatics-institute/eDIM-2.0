class DrugThreshold < ActiveRecord::Base
  belongs_to :drug, :foreign_key => :drug_id
  has_many :drug_threshold_sets, :foreign_key => :threshold_id
  validates :threshold, :presence => true
  validates :threshold, :numericality => { :only_integer => true }
  validates :threshold, :numericality => { :greater_than => 0 }
  validates_associated :drug
end
