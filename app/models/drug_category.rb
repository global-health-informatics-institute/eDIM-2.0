class DrugCategory < ActiveRecord::Base
  has_many :drugs
  
  # Automatically trim whitespace from category
  before_save :normalize_category
  
  private
  
  def normalize_category
    self.category = self.category.strip if self.category.present?
  end
end
