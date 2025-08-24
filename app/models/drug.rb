class Drug < ActiveRecord::Base
  belongs_to :drug_category, :foreign_key =>  :drug_category_id
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