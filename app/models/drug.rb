class Drug < ActiveRecord::Base
  belongs_to :drug_category, :foreign_key =>  :drug_category_id
  def ingredient
    temp = self.name.downcase.gsub(self.dose_form.downcase, "")
    return temp.gsub(self.dose_strength.downcase, "").squish
  end

  def category
    return self.drug_category.category
  end

end