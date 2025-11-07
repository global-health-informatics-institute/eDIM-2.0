# app/controllers/prepack_labels_controller.rb
class PrepackLabelsController < ApplicationController
  before_action :ensure_location

  def new

    @has_prescribe = false
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

    # Partial for AJAX, not a full page
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