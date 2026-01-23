class AlertsController < ApplicationController
  def inventory
    location_id = session[:location] || User.current.location_id
    today = Date.current

    # Low stock items
    low_stock = GeneralInventory
      .where(location_id: location_id)
      .where("current_quantity > 0 AND current_quantity <= COALESCE(reorder_level, 10)")
      .where(voided: false)
      .includes(:drug)

    # Near expiry items
    near_expiry = GeneralInventory
      .where(location_id: location_id)
      .where.not(expiration_date: nil)
      .where(expiration_date: today..(today + 30.days))
      .where("current_quantity > 0")
      .where(voided: false)
      .includes(:drug)

    # Prepacks with low stock
    prepacks_low = Prepack
      .where(location_id: location_id, voided: 0, deleted: 0)
      .where("current_num_packs > 0 AND current_num_packs <= ?", 5)
      .includes(:drug)

    render json: {
      low_stock: low_stock.map { |i|
        {
          type: "inventory",
          gn_identifier: i.gn_identifier,
          gn_sequence: i.gn_sequence,
          drug: i.drug.name,
          remaining: i.current_quantity
        }
      },

      near_expiry: near_expiry.map { |i|
        {
          type: "inventory",
          gn_identifier: i.gn_identifier,
          gn_sequence: i.gn_sequence,
          drug: i.drug.name,
          expiry_date: i.expiration_date,
          days_left: (i.expiration_date - today).to_i
        }
      },

      prepacks_low: prepacks_low.map { |p|
        {
          type: "prepack",
          prepack_id: p.id,
          drug: p.drug.name,
          remaining_packs: p.current_num_packs
        }
      }
    }
  end
end