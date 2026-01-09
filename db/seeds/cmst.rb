require "csv"

path = Rails.root.join("db", "seeds", "cmst_druglist.csv")

puts "→ Importing CMST drug list"

CSV.foreach(path, headers: true) do |row|
  category = DrugCategory.find_or_create_by!(
    category: row["Category"]
  ) do |cat|
    cat.voided = false
  end

  Drug.find_or_create_by!(
    name: row["Item Description"]
  ) do |drug|
    drug.item_code        = row["Item Code"]
    drug.dose_strength    = row["Strength"]
    drug.dose_form        = row["Dosage Form"]
    drug.drug_category_id = category.drug_category_id
    drug.voided           = false
  end
end

puts "CMST drugs imported"