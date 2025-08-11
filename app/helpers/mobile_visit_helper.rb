module MobileVisitHelper
  def list_products(items)
    products = []
    (items || []).each do |item|
      gn_item = GeneralInventory.find_by_gn_identifier(item.gn_identifier)
      next if gn_item.blank?
      products << {"product" => gn_item.drug_name, "exp_date" => gn_item.expiration_date,"id" => item.id,"voidable" => item.voidable,
        "amount_taken" => item.amount_taken, "amount_used" => item.amount_used, "bottle_id" => item.gn_identifier}
    end
    return products
  end
end
