class Drug < ActiveRecord::Base
  belongs_to :drug_category, :foreign_key =>  :drug_category_id
  has_many :general_inventories, foreign_key: :drug_id
  
  # Automatically trim whitespace from name
  before_save :normalize_name
  
  private
  
  def normalize_name
    self.name = self.name.strip if self.name.present?
  end

def ingredient
  temp = self.name.to_s.downcase

  if self.dose_form.present?
    temp = temp.gsub(self.dose_form.to_s.downcase, "")
  end

  if self.dose_strength.present?
    temp = temp.gsub(self.dose_strength.to_s.downcase, "")
  end

  temp.squish
end

  def category
    return self.drug_category.category
  end

end