class PrepackLabelsController < ApplicationController
  before_action :ensure_location
  before_action :set_pending_requests_count
  before_action :set_prepack, only: [:edit, :update]
  before_action :set_prepack, only: [:edit, :update]

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
    
    # Check if @prepacks was set by load_prepack_inventory
    if @prepacks.nil?
      @prepacks = Prepack.where(deleted: false, voided: false).order(created_at: :desc)
    end
    
    # Load current quantities from general inventory
    gn_identifiers = @prepacks.map(&:gn_identifier).compact
    inventories = GeneralInventory.where(gn_identifier: gn_identifiers)
                                  .pluck(:gn_identifier, :current_quantity)
                                  .to_h
    
    @prepacks.each do |prepack|
      # Get current bottle quantity from inventory
      bottle_quantity = inventories[prepack.gn_identifier] || 0
      prepack.instance_variable_set(:@bottle_quantity, bottle_quantity)
    end
  end

  # edit and update actions for prepack labels
  def edit
    # Check if prepack can be edited (must have at least one undispensed label)
    unless can_edit_prepack?(@prepack)
      respond_to do |format|
        format.html { redirect_to general_inventory_prepack_labels_path, alert: "Cannot edit: All packs for this prepack have been dispensed" }
        format.json { render json: { error: "Cannot edit: All packs for this prepack or batch  have been dispensed" }, status: :forbidden }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to general_inventory_prepack_labels_path, notice: "Use Edit button" }  
      format.json { render json: render_prepack_json(@prepack) }                                
    end
  end

  def update
    # Check if prepack can be edited (must have at least one undispensed label)
    unless can_edit_prepack?(@prepack)
      respond_to do |format|
        format.html { redirect_to general_inventory_prepack_labels_path, alert: "Cannot update: All packs for this prepack have been dispensed" }
        format.json { render json: { success: false, error: "Cannot update: All packs for this prepack have been dispensed" }, status: :forbidden }
      end
      return
    end

    puts " UPDATE DEBUG: #{@prepack.id} | BEFORE=#{@prepack.quantity_per_pack}"
  puts " PARAMS: #{params.inspect}"
  
  data = build_update_data
  puts " DATA: #{data.inspect}"
  
  begin
    Prepack.transaction do
      @prepack.update!(data)
      sync_prepack_labels!(@prepack, data[:current_num_packs].to_i)
    end

    puts "SAVED! AFTER=#{@prepack.quantity_per_pack}"
    respond_to do |format|
      format.html { 
        redirect_to general_inventory_prepack_labels_path, notice: 'Updated successfully' 
      }
      format.json { 
        render json: { 
          success: true, 
          prepack: render_prepack_json(@prepack),
          message: 'Updated successfully'
        } 
      }
    end
  rescue => e
    Rails.logger.error("Prepack update failed: #{e.message}")
    puts "FAILED: #{@prepack.errors.full_messages}"
    respond_to do |format|
      format.html { 
        redirect_to general_inventory_prepack_labels_path, alert: "Update failed: #{e.message}"
      }
      format.json { 
        render json: { 
          success: false, 
          error: (@prepack.errors.full_messages.to_sentence.presence || e.message)
        }, status: :unprocessable_entity 
      }
    end
  end
end

private

def set_prepack
  @prepack = Prepack.find(params[:id])
end

# Check if a prepack can be edited
# Returns true if there is at least one undispensed label
def can_edit_prepack?(prepack)
  return false if prepack.nil?

  # Primary rule: editable when at least one label has not been dispensed yet.
  undispensed_count = prepack.prepack_labels.where(dispensed: [false, nil]).count
  return true if undispensed_count > 0

  # Fallback for inconsistent legacy records:
  # if total dispensed labels is still less than intended packs, keep editable.
  dispensed_count = prepack.prepack_labels.where(dispensed: true).count
  prepack.num_packs.to_i > dispensed_count
end

def render_prepack_json(prepack = @prepack)
  dose = prepack.directions.to_s.match(/(\d+(?:\.\d+)?)/)&.[](1) || '2'
  frequency = case prepack.directions.to_s.downcase
              when /once|one|daily/ then 'OD'
              when /two|twice/ then 'BD'
              when /three|thrice/ then 'TDS'
              when /four/ then 'QID'
              else 'BD'
              end
  administration = case prepack.directions.to_s.downcase
                  when /take/ then 'oral'
                  when /apply/ then 'topical'
                  when /inject/ then 'injection'
                  when /inhale/ then 'respiratory'
                  else 'oral'
                  end
  
  qty_per_pack = prepack.quantity_per_pack.to_f
  freq_multiplier = { 'OD' => 1, 'BD' => 2, 'TDS' => 3, 'QID' => 4 }[frequency] || 2
  raw_duration = qty_per_pack > 0 ? (qty_per_pack / (dose.to_f * freq_multiplier)) : 7
  duration = [raw_duration.ceil, 1].max
  
  {
    id: prepack.id,
    drug_name: prepack.drug&.name,
    bottle_id: prepack.bottle_id,
    gn_identifier: prepack.gn_identifier,
    bottle_quantity: GeneralInventory.find_by(gn_identifier: prepack.gn_identifier)&.current_quantity.to_i,
    directions: prepack.directions,
    num_packs: prepack.current_num_packs.nonzero? || prepack.num_packs,
    quantity_per_pack: prepack.quantity_per_pack,
    current_num_packs: prepack.current_num_packs,
    dose: dose,
    duration: duration.to_s,
    frequency: frequency,
    administration: administration,
    times: normalize_times(prepack.times)
  }
end

def build_update_data
  new_quantity_per_pack = params[:quantity_per_pack].to_i
  # current_num_packs is derived from existing undispensed labels in this batch.
  # Editing must not add/remove labels.
  new_current_num_packs = @prepack.prepack_labels.where(
    dispensed: false, deleted: false, voided: false, dispensed_by: nil
  ).count
  dose = params[:dose]&.strip || '2'
  frequency = params[:frequency] || 'BD'
  administration = params[:administration] || 'oral'
  normalized_times = normalize_times(params[:times])
  
  freq_words = {
    'OD' => 'Once', 'BD' => 'Two', 'TDS' => 'Three', 'QID' => 'Four',
    'QHR' => 'Twenty Four', 'Q2HRS' => 'Twelve', 'Q4HRS' => 'Six', 'EOD' => 'One', 'QN' => 'One', 'QWK' => 'One'
  }
  route_words = { 'oral' => 'Take', 'topical' => 'Apply', 'injection' => 'Inject', 'respiratory' => 'Inhale', 'other' => 'Take' }
  new_directions = "#{route_words[administration] || 'Take'} #{dose} #{freq_words[frequency] || 'Two'} Times A Day"
  
  {
    quantity_per_pack: new_quantity_per_pack,
    current_num_packs: new_current_num_packs,
    directions: new_directions,
    total_quantity: new_quantity_per_pack * new_current_num_packs,
    times: normalized_times.to_json
  }
end

def normalize_times(raw_times)
  case raw_times
  when Array
    raw_times.map(&:to_s).map(&:strip).reject(&:blank?)
  when String
    begin
      parsed = JSON.parse(raw_times)
      parsed.is_a?(Array) ? parsed.map(&:to_s).map(&:strip).reject(&:blank?) : []
    rescue JSON::ParserError
      raw_times.split(',').map(&:strip).reject(&:blank?)
    end
  else
    []
  end
end

def sync_prepack_labels!(prepack, _target_num_packs)
  now = Time.current

  # Editing must never create/remove label rows. Keep operations within the same batch.
  editable_labels = prepack.prepack_labels.where(voided: false, dispensed: false, dispensed_by: nil)

  mismatched_ids = editable_labels
    .joins(:bottle)
    .where.not(general_inventories: { gn_inventory_id: prepack.bottle_id })
    .pluck(:id)

  if mismatched_ids.any?
    prepack.prepack_labels.where(id: mismatched_ids).update_all(bottle_id: prepack.bottle_id, updated_at: now)
  end

  remaining_undispensed = prepack.prepack_labels.where(deleted: false, voided: false, dispensed: false, dispensed_by: nil).count

  # Always persist an edit-side write on active labels so prepack_labels stays in sync transactionally.
  # Only update labels where dispensed_by is null
  prepack.prepack_labels
         .where(deleted: false, voided: false, dispensed: false, dispensed_by: nil)
         .update_all(bottle_id: prepack.bottle_id, updated_at: now)

  prepack.update!(current_num_packs: remaining_undispensed)
end

def next_label_index_for(gn_identifier)
  last_label = PrepackLabel
    .where("label_identifier LIKE ?", "PK-#{gn_identifier}-%")
    .order(Arel.sql("CAST(SUBSTRING_INDEX(label_identifier, '-', -1) AS UNSIGNED) DESC"))
    .first

  last_label ? last_label.label_identifier.split('-').last.to_i : 0
end

public

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
      else
        start_date = Date.today.beginning_of_day.utc
        end_date   = Date.today.end_of_day.utc
      end
    rescue => e
      start_date = Date.today.beginning_of_day.utc
      end_date   = Date.today.end_of_day.utc
    end

    locations = filters[:locations] || ['All Locations']
    duration = filters["report_duration"] || filters[:report_duration] || 'Daily'

    # Set report title
    @report_type = case duration
                  when 'Daily'
                    "Prepack Report for #{l(start_date.to_date, format:'%d %B, %Y')}"
                  when 'Weekly', 'Monthly', 'Range'
                    "Prepack Report from #{l(start_date.to_date, format:'%d %B, %Y')} to #{l(end_date.to_date, format:'%d %B, %Y')}"
                  else
                    "Prepack Report for #{l(Date.today, format:'%d %B, %Y')}"
                  end

    # Base query and records
    base_query = Prepack.joins(:drug)
                        .where(created_at: start_date..end_date)
                        .order("prepacks.created_at DESC")

    record_count = base_query.count

    @records = base_query.select("prepacks.*, drugs.name as drug_name") || Prepack.none

    # Location filter
    if locations.present? && !locations.include?('All Locations')
      location_ids = Location.where(name: locations).pluck(:location_id)
      bottle_ids = GeneralInventory.where(location_id: location_ids).pluck(:gn_identifier).uniq
      if bottle_ids.present?
        @records = @records.where(gn_identifier: bottle_ids)
      else
        @records = Prepack.none
      end
    end

    @records ||= Prepack.none

    # Collect ids
    prepack_ids = @records.pluck(:id)

    # Get damages
    damage_records =
      if prepack_ids.present?
        Damage.where(prepack_id: prepack_ids)
              .where(damage_date: start_date..end_date)
              .group(:prepack_id)
              .sum(:quantity)
      else
        {}
      end

    # Totals initialization
    @total_packs = 0
    @total_dispensed = 0
    @total_damaged = 0
    @total_quantity = 0
    @total_original_packs = 0

    # Ensure array
    @prepacks = @records.to_a || []

    # preload general inventory quantities
    gn_identifiers = @prepacks.map(&:gn_identifier).compact
    inventories = GeneralInventory.where(gn_identifier: gn_identifiers)
                                  .pluck(:gn_identifier, :current_quantity)
                                  .to_h

    @prepacks.each do |prepack|
      dispensed_count = prepack.prepack_labels.where(
        dispensed: true,
        deleted: false,
        voided: false
      ).count rescue 0

      damages_count = damage_records[prepack.id].to_i
      prepack.instance_variable_set(:@damages_count, damages_count)

      original_packs_for_this_prepack = prepack.num_packs + damages_count

      # Get the current bottle quantity from inventory
      bottle_quantity = inventories[prepack.gn_identifier] || 0
      
      # Set it on the prepack object for use in the view
      prepack.instance_variable_set(:@bottle_quantity, bottle_quantity)

      @total_packs += prepack.num_packs.to_i
      @total_dispensed += dispensed_count.to_i
      @total_damaged += damages_count.to_i
      @total_quantity += (prepack.quantity_per_pack.to_i * prepack.num_packs.to_i)
      @total_original_packs += original_packs_for_this_prepack.to_i
    end

    @total_remaining = @total_original_packs - @total_dispensed - @total_damaged - @total_damaged

    render 'list', layout: 'application'
  rescue => e

    raise
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
      calculated_end = selected_date + 1.month - 1.day
      final_end = [calculated_end, Date.today].min
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

  private

  # Load prepack inventory for new prepack view
  def load_prepack_inventory
    prepacks = Prepack.includes(:drug, :prepack_labels)
                      .where(deleted: false, voided: false)
                      .order(created_at: :desc)

    inventory = prepacks.map do |prepack|
      labels = prepack.prepack_labels

      {
        id: prepack.id,
        bottle_id: prepack.bottle_id,
        gn_identifier: prepack.gn_identifier,
        drug_name: prepack.drug.name,
        total_packs_created: prepack.num_packs,
        quantity_per_pack: prepack.quantity_per_pack,
        packs_remaining: labels.where(dispensed: [false, nil]).count,
        packs_dispensed: labels.where(dispensed: true).count,
        status: prepack.status,
        created_at: prepack.created_at,
        bottle_quantity: GeneralInventory.find_by(gn_identifier: prepack.gn_identifier)&.current_quantity || 0
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
