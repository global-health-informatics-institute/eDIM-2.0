require "csv"

path = Rails.root.join("db", "seeds", "drugs.csv")

puts "→ Importing drugs"

CSV.foreach(path, headers: true) do |row|
  category = DrugCategory.find_or_create_by!(
    category: row["Category"]
  ) do |cat|
    cat.voided = false
  end

  Drug.find_or_create_by!(
    name: row["Drug Name"]
  ) do |drug|
    drug.dose_strength    = row["Strength"]
    drug.dose_form        = row["Dose Form"]
    drug.par_level        = row["Par level"]
    drug.drug_category_id = category.drug_category_id
    drug.voided           = false
  end
end

puts "Drugs imported"