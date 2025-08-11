require 'csv'
namespace :cmst do

  desc 'Load central medical stores catalogue data'

  task load: :environment do
    CSV.foreach("#{Rails.root}/db/cmst_druglist.csv",{:headers=>:first_row}) do |row|

      drug_category = DrugCategory.where(category: row[4].squish).first_or_initialize
      drug_category.save if drug_category.id.blank?

      drug_name = row[1].to_s.squish
      drug = Drug.where(name: drug_name).first_or_initialize
      drug.drug_category_id = drug_category.id
      drug.dose_strength = row[2] rescue 'NA'
      drug.dose_form = row[3] rescue 'Other'
      drug.save

      unless (row[5].blank? || row[5].to_i == 0)
        threshold = DrugThreshold.where(drug_id: drug.id).first_or_initialize
        threshold.threshold = row[5].to_i
        threshold.save
      end

    end
  end

  task map: :environment do
    CSV.foreach("#{Rails.root}/db/cmst_drug_map.csv",{:headers=>:first_row}) do |row|
      drug_category = DrugCategory.where(category: row[2].squish).first_or_initialize
      drug_category.save if drug_category.id.blank?

      drug_name = row[0].to_s.squish
      drug = Drug.where(name: drug_name).first

      next if drug.blank?
      drug.name = (row[1].blank? ? drug.name : row[1].to_s.squish)
      drug.drug_category_id = drug_category.id
      drug.save
    end
  end
end