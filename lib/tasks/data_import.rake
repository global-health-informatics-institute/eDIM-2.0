require 'csv'
require 'securerandom'

# This task imports drug categories and drugs from a CSV file.
namespace :import do
  desc "Import drug categories and drugs from CSV"
  task drugs: :environment do
    csv_path = Rails.root.join('db', 'drugs.csv')

    unless File.exist?(csv_path)
      puts "CSV file not found at #{csv_path}"
      exit 1
    end

    puts "Starting import of drug categories..."

    # Import categories
    categories = CSV.read(csv_path, headers: true).map { |row| row['Category'].to_s.strip }.uniq

    categories.each do |cat_name|
      next if cat_name.empty?

      category = DrugCategory.find_or_initialize_by(category: cat_name)
      if category.new_record?
        category.voided = false
        category.created_at = Time.now
        category.updated_at = Time.now
        category.save!
        puts "Created category: #{cat_name}"
      else
        puts "Category already exists: #{cat_name}"
      end
    end

    puts "Importing drugs..."

    # Import drugs
    CSV.foreach(csv_path, headers: true) do |row|
      category = DrugCategory.find_by(category: row['Category'].to_s.strip)
      next unless category

      dose_strength = row['Strength'].to_s.strip.presence
      dose_form = row['Dose Form'].to_s.strip.presence
      par_level_str = row['Par level'].to_s.strip

      par_level = (par_level_str =~ /\A\d+\z/) ? par_level_str.to_i : nil

      drug = Drug.find_or_initialize_by(
        name: row['Drug Name'].to_s.strip,
        dose_strength: dose_strength,
        dose_form: dose_form
      )

      if drug.new_record?
        drug.drug_category_id = category.drug_category_id
        drug.par_level = par_level
        drug.voided = false if drug.respond_to?(:voided)
        drug.created_at = Time.now
        drug.updated_at = Time.now
        drug.save!
        puts "Created drug: #{drug.name} (#{dose_strength} #{dose_form})"
      else
        puts "Drug already exists: #{drug.name} (#{dose_strength} #{dose_form})"
      end
    end

    puts "Drug import complete."
  end
end