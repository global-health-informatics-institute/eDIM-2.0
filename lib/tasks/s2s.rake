require 'csv'
namespace :s2s do

  desc 'Load shoulder to shoulder drug list'

  task load: :environment do
    CSV.foreach("#{Rails.root}/db/drugs.csv",{:headers=>:first_row}) do |row|

      drug_category = DrugCategory.where(category: row[4].squish).first_or_initialize
      drug_category.save if drug_category.id.blank?

      drug_name = ((row[0].to_s rescue "") + " " + (row[1].to_s rescue "") + " " + (row[2].to_s rescue "")).squish
      drug = Drug.where(name: drug_name).first_or_initialize
      drug.drug_category_id = drug_category.id
      drug.name = drug_name
      drug.dose_strength = (row[1].blank? ? nil : row[1].squish)
      drug.dose_form = (row[2].blank? ? nil : row[2].squish)
      drug.save

      unless (row[3].blank? || row[3].to_i == 0)
        threshold = DrugThreshold.where(drug_id: drug.id).first_or_initialize
        threshold.threshold = row[3].to_i
        threshold.save
      end
    end
  end
end