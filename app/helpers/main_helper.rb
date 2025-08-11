module MainHelper
  def compile_report(dispensations,inventory,late_disp)
    records = {}
    (inventory || []).each do |item|
      records[item.drug_id] = {"name" => Drug.find(item.drug_id).name, "available" => 0, "dispensed" => 0} if records[item.drug_id].blank?
      records[item.drug_id]["available"] += item.current_quantity
    end

    (dispensations || []).each do |item|
      records[item.drug_id] = {"name" => Drug.find(item.drug_id).name, "available" => 0, "dispensed" => 0} if records[item.drug_id].blank?
      records[item.drug_id]["dispensed"] += item.quantity
    end

    (late_disp || []).each do |item|
      records[item.drug_id] = {"name" => Drug.find(item.drug_id).name, "available" => 0, "dispensed" => 0} if records[item.drug_id].blank?
      records[item.drug_id]["available"] += item.quantity
    end

    return records
  end

  def stores_report(issues,receipts,current_stock,later_issues,drug_map)

    #pre-processing report information
    records = {}
    (receipts || []).each do |item|
      records[item.drug_id] = {'name' => Drug.find(item.drug_id).name, 'current' => 0, 'received' => 0, 'issued' => 0} if records[item.drug_id].blank?
      records[item.drug_id]['received'] += item.received_quantity
    end
    (current_stock || []).each do |item|
      records[item.drug_id] = {'name' => Drug.find(item.drug_id).name, 'current' => 0, 'received' => 0, 'issued' => 0} if records[item.drug_id].blank?
      records[item.drug_id]['current'] += item.current_quantity
    end

    (issues || []).each do |item|
      next if records[drug_map[item.inventory_id.to_i]].blank?
      records[drug_map[item.inventory_id.to_i]] = {'name' => Drug.find(drug_map[item.inventory_id.to_i]).name,'current' => 0,
                                              'received' => 0,'issued' => 0} if records[drug_map[item.inventory_id.to_i]].blank?
      records[drug_map[item.inventory_id.to_i]]['issued'] += item.quantity
    end

    (later_issues || []).each do |item|
      next if records[drug_map[item.inventory_id.to_i]].blank?
      records[drug_map[item.inventory_id.to_i]] = {'name' => Drug.find(drug_map[item.inventory_id.to_i]).name,'current' => 0,
                                              'received' => 0,'issued' => 0} if records[drug_map[item.inventory_id.to_i]].blank?
      records[drug_map[item.inventory_id.to_i]]['current'] += item.quantity
    end

    return records

  end
end
