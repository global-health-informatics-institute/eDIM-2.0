map_path = Rails.root.join("db", "seeds", "cmst_drug_map.csv")

puts "→ Mapping CMST names"

CSV.foreach(map_path, headers: true) do |row|
  drug = Drug.find_by(name: row["old_name"])
  next unless drug

  drug.update!(
    name: row["csmt_name"]
  )
end

puts "CMST drug mapping applied"
