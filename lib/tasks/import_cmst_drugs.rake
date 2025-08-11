# lib/tasks/import_cmst_drugs.rake

namespace :import do
  desc "Import CMST drug list from CSV into drugs table"
  task cmst_drugs: :environment do
    require 'csv'

    file_path = Rails.root.join('db', 'cmst_druglist.csv')

    unless File.exist?(file_path)
      puts "CSV file not found at #{file_path}"
      exit
    end

    puts "Importing CMST drug list from #{file_path}..."

    imported = 0
    updated = 0

    CSV.foreach(file_path, headers: true) do |row|
        category_name = row['Category']&.strip
        next unless category_name.present?

        category = DrugCategory.find_or_create_by!(category: category_name)

        drug_attrs = {
            name: row['Item Description']&.strip,
            dose_strength: row['Strength']&.strip,
            dose_form: row['Dosage Form']&.strip,
            item_code: row['Item Code']&.strip,
            drug_category_id: category.id
        }

        drug = Drug.find_or_initialize_by(item_code: drug_attrs[:item_code])
        if drug.new_record?
            drug.assign_attributes(drug_attrs)
            drug.save!
            imported += 1
        else
            drug.update!(drug_attrs)
            updated += 1
        end
        puts row.to_h
    end

    puts "Import completed: #{imported} new drugs added, #{updated} updated."
  end
end