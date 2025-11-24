# app/controllers/prepack_labels_controller.rb
class PrepackLabelsController < ApplicationController
  before_action :ensure_location
  def index
    @prepack_inventory = Prepack.joins(:drug)
                                .where(prepacked_by_id: User.current.id) # or adjust based on your access logic
                                .select("
                                  prepacks.id,
                                  prepacks.bottle_id,
                                  prepacks.gn_identifier,
                                  drugs.name as drug_name,
                                  prepacks.num_packs as total_packs_created,
                                  prepacks.quantity_per_pack,
                                  prepacks.status,
                                  prepacks.created_at,
                                  (SELECT COUNT(*) FROM prepack_labels WHERE prepack_labels.prepack_id = prepacks.id AND prepack_labels.dispensed = 0) as packs_remaining,
                                  (SELECT COUNT(*) FROM prepack_labels WHERE prepack_labels.prepack_id = prepacks.id AND prepack_labels.dispensed = 1) as packs_dispensed
                                ")
                                .order("prepacks.created_at DESC")
  end
  def new
    # For creating new prepacks
    @prepack = Prepack.new
    
    # Load existing prepack inventory for display
    @prepack_inventory = load_prepack_inventory
  end

  private

  def load_prepack_inventory
    prepacks = Prepack.includes(:drug, :prepack_labels)
                     .where(prepacked_by_id: User.current.id)
                     .order(created_at: :desc)
    
    prepacks.map do |prepack|
      labels = prepack.prepack_labels
      {
        bottle_id: prepack.bottle_id,
        gn_identifier: prepack.gn_identifier,
        drug_name: prepack.drug.name,
        total_packs_created: prepack.num_packs,
        quantity_per_pack: prepack.quantity_per_pack,
        packs_remaining: labels.where(dispensed: false).count,
        packs_dispensed: labels.where(dispensed: true).count,
        status: prepack.status,
        created_at: prepack.created_at
      }
    end
  end

  def show
    Rails.logger.info ">>> [PrepackLabels#show] Searching bottle=#{params[:id]} location=#{session[:location]}"

    @bottle = GeneralInventory.find_by(
      gn_identifier: params[:id].to_s.strip,
      location_id: session[:location],
      voided: false
    )

    if @bottle.blank?
      render plain: "Bottle with ID #{params[:id]} not found in this location", status: :not_found and return
    end

    @drug = @bottle.drug
    @records = Issue.where(inventory_id: @bottle.gn_inventory_id).order(issue_date: :desc)

    # Partial for AJAX
    render partial: 'prepack_labels/show',
          locals: { bottle: @bottle, drug: @drug, records: @records },
          layout: false
  end


  def ajax_bottle_prepack
    Rails.logger.info ">>> [PrepackLabels#ajax_bottle_prepack] Searching bottle=#{params[:id]} location=#{session[:location]}"

    entry = GeneralInventory.includes(:drug).find_by(
      gn_identifier: params[:id].to_s.strip,
      location_id: session[:location],
      voided: false
    )

    if entry.blank?
      render json: { error: 'Bottle not found' }, status: :not_found
    else
      render json: {
        id: entry.id,
        gn_identifier: entry.gn_identifier,
        drug_name: entry.drug.name,
        current_quantity: entry.current_quantity,
        expiration_date: entry.expiration_date
      }
    end
  end

  private

  def ensure_location
    # Ensure session[:location] is set like in GeneralInventoryController
    session[:location] ||= Location.current.id rescue nil
  end
end