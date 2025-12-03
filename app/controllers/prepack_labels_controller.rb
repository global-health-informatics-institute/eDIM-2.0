class PrepackLabelsController < ApplicationController
  before_action :ensure_location
  before_action :set_pending_requests_count

  def index
    @prepack_inventory = Prepack.joins(:drug)
                                .where(prepacked_by_id: User.current.id, deleted: false, voided: false)
                                .select("
                                  prepacks.id,
                                  prepacks.bottle_id,
                                  prepacks.gn_identifier,
                                  drugs.name AS drug_name,
                                  prepacks.num_packs AS total_packs_created,
                                  prepacks.quantity_per_pack,
                                  prepacks.status,
                                  prepacks.created_at,

                                  (SELECT COUNT(*) FROM prepack_labels 
                                      WHERE prepack_labels.prepack_id = prepacks.id 
                                      AND prepack_labels.dispensed = 0
                                      AND prepack_labels.deleted = 0
                                      AND prepack_labels.voided = 0
                                  ) AS packs_remaining,

                                  (SELECT COUNT(*) FROM prepack_labels 
                                      WHERE prepack_labels.prepack_id = prepacks.id 
                                      AND prepack_labels.dispensed = 1
                                      AND prepack_labels.deleted = 0
                                      AND prepack_labels.voided = 0
                                  ) AS packs_dispensed
                                ")
                                .order("prepacks.created_at DESC")
  end

  def new
    @prepack = Prepack.new
    @prepack_inventory = load_prepack_inventory
  end

  def delete
    prepack = Prepack.find_by(id: params[:id], deleted: false)

    if prepack.nil?
      redirect_to general_inventory_prepack_labels_path, alert: "Prepack not found."
      return
    end

    prepack.update(deleted: true)
    PrepackLabel.where(prepack_id: prepack.id).update_all(deleted: true)

    redirect_to general_inventory_prepack_labels_path, notice: "Prepack removed successfully."
  end

  # SHOW BOTTLE HISTORY
  def show
    Rails.logger.info ">>> [PrepackLabels#show] Searching bottle=#{params[:id]} location=#{session[:location]}"

    @bottle = GeneralInventory.find_by(
      gn_identifier: params[:id].to_s.strip,
      location_id: session[:location],
      voided: false
    )

    if @bottle.blank?
      render plain: "Bottle with ID #{params[:id]} not found in this location",
             status: :not_found and return
    end

    @drug = @bottle.drug
    @records = Issue.where(inventory_id: @bottle.gn_inventory_id).order(issue_date: :desc)

    render partial: "prepack_labels/show",
           locals: { bottle: @bottle, drug: @drug, records: @records },
           layout: false
  end

  def ajax_bottle_prepack
  
    entry = GeneralInventory.includes(:drug).find_by(
      gn_identifier: params[:id].to_s.strip,
      location_id: session[:location],
      voided: false
    )

    if entry.blank?
      render json: { error: "Bottle not found" }, status: :not_found
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

  def destroy
    prepack = Prepack.find_by(id: params[:id])

    if prepack.nil?
      flash[:alert] = "Prepack not found"
      redirect_to prepack_labels_path and return
    end

    # Delete the batch and all labels
    prepack.update(deleted: true)
    prepack.prepack_labels.update_all(deleted: true)

    flash[:notice] = "Prepack removed successfully"
    redirect_to prepack_labels_path
  end

  # PREPACK REPORT METHODS
  def select
    # Get all locations that have prepack activities
    locations_with_prepacks = Location.select(:location_id).distinct.pluck(:location_id)
    @locations = ['All Locations'] + Location.where(location_id: locations_with_prepacks).pluck(:name)
    render layout: 'touch'
  end

  def report
    # Determine date range based on report_duration
    start_date, end_date = case params[:report_duration]
    when 'Daily'
      selected_date = params[:start_date].to_date
      [selected_date.beginning_of_day, selected_date.end_of_day]

    when 'Weekly'
      selected_date = params[:start_date].to_date
      calculated_end = selected_date + 6.days
      final_end = [calculated_end, Date.today].min
      [selected_date.beginning_of_day, final_end.end_of_day]

    when 'Monthly'
      selected_date = params[:start_date].to_date
      month_end = selected_date.end_of_month
      final_end = [month_end, Date.today].min
      [selected_date.beginning_of_day, final_end.end_of_day]

    when 'Range'
      start_date = params[:start_date].to_date
      end_date   = params[:end_date].to_date
      [start_date.beginning_of_day, end_date.end_of_day]

    else
      today = Date.today
      [today.beginning_of_day, today.end_of_day]
    end

    # Determine locations
    if Location.find(session[:location]).name.downcase != "backstore"
      selected_locations = [session[:location]]
    else
      selected_locations = params[:locations] || ['All Locations']
    end

    # Store filters in session as ISO strings
    session[:prepack_report_filter] = {
      start_date: start_date.iso8601,
      end_date:   end_date.iso8601,
      locations:  selected_locations,
      report_duration: params[:report_duration]
    }

    redirect_to '/prepack_labels/list'
  end

  def list
    # Try to get filters from session, use default if not found
    filters = session[:prepack_report_filter] || {}

    # Parse dates from session
    begin
      start_date_raw = filters["start_date"] || filters[:start_date]
      end_date_raw   = filters["end_date"]   || filters[:end_date]

      if start_date_raw && end_date_raw
        start_date = Time.iso8601(start_date_raw)
        end_date   = Time.iso8601(end_date_raw)
        Rails.logger.info ">>> Successfully parsed dates from session"
      else
        Rails.logger.info ">>> Using default dates"
        start_date = Date.today.beginning_of_day.utc
        end_date   = Date.today.end_of_day.utc
      end
      
    rescue => e
      Rails.logger.error "Error parsing dates: #{e.message}"
      # Use default dates on error
      start_date = Date.today.beginning_of_day.utc
      end_date = Date.today.end_of_day.utc
    end
    
    locations = filters[:locations] || ['All Locations']
    duration = filters["report_duration"] || filters[:report_duration] || 'Daily'
    
    # Set report title - use local time for display
    @report_type = case duration
                  when 'Daily'
                    "Prepack Report for #{l(start_date.to_date, format:'%d %B, %Y')}"
                  when 'Weekly'
                    "Prepack Report from #{l(start_date.to_date, format:'%d %B, %Y')} to #{l(end_date.to_date, format:'%d %B, %Y')}"
                  when 'Monthly'
                    "Prepack Report from #{l(start_date.to_date, format:'%d %B, %Y')} to #{l(end_date.to_date, format:'%d %B, %Y')}"
                  when 'Range'
                    "Prepack Report from #{l(start_date.to_date, format:'%d %B, %Y')} to #{l(end_date.to_date, format:'%d %B, %Y')}"
                  else
                    "Prepack Report for #{l(Date.today, format:'%d %B, %Y')}"
                  end

    # Fetch prepack records within date range
    base_query = Prepack.joins(:drug)
                        .where(created_at: start_date..end_date)
                        .order("prepacks.created_at DESC")

    # Get count first
    record_count = base_query.count
    Rails.logger.info ">>> Found #{record_count} prepack records in UTC date range"

    @records = base_query.select("prepacks.*, drugs.name as drug_name")

    unless locations.include?('All Locations')
      location_ids = Location.where(name: locations).pluck(:location_id)
      
      bottle_ids = GeneralInventory.where(location_id: location_ids)
                                  .pluck(:gn_identifier)
                                  .uniq
      
      @records = @records.where(gn_identifier: bottle_ids)
      Rails.logger.info ">>> After location filter: #{@records.count} records"
    end

    # Get all prepack bottle IDs for damages query
    prepack_bottle_ids = @records.pluck(:bottle_id).uniq
    
    # Get damages for all bottles in one query (optimized)
    damages_by_bottle = Damage.where(general_inventory_id: prepack_bottle_ids)
                            .where(damage_date: start_date..end_date)
                            .group(:general_inventory_id)
                            .sum(:quantity)

    # Calculate totals for the report
    @total_packs = 0
    @total_dispensed = 0
    @total_damaged = 0
    @total_quantity = 0
    
    # Load records as array for iteration
    @prepacks = @records.to_a
    
    @prepacks.each do |prepack|
      dispensed_count = prepack.prepack_labels.where(dispensed: true, deleted: false, voided: false).count
      damages_count = damages_by_bottle[prepack.bottle_id] || 0
      
      # Store damages_count on the prepack object for use in view
      prepack.instance_variable_set(:@damages_count, damages_count)
      
      @total_packs += prepack.num_packs
      @total_dispensed += dispensed_count
      @total_damaged += damages_count
      @total_quantity += prepack.quantity_per_pack * prepack.num_packs
    end
    
    @total_remaining = @total_packs - @total_dispensed - @total_damaged

    render 'list', layout: 'application'
  end

  private

  def load_prepack_inventory
    prepacks = Prepack.includes(:drug, :prepack_labels)
                      .where(prepacked_by_id: User.current.id, deleted: false, voided: false)
                      .order(created_at: :desc)

    inventory = prepacks.map do |prepack|
      labels = prepack.prepack_labels.where(deleted: false, voided: false)

      {
        id: prepack.id,
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

    inventory.sort_by { |p| p[:packs_dispensed] == p[:total_packs_created] ? 1 : 0 }
  end

  # Ensure user location exists
  def ensure_location
    session[:location] ||= Location.current.id rescue nil
  end

  def set_pending_requests_count
    location = Location.find(session[:location])

    if location.name.downcase == "backstore"
      @pending_requests_count = Request.where(fulfilled: false).count
    else
      @pending_requests_count = Request.where(location_id: session[:location], fulfilled: false).count
    end
  end
end