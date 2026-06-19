class GeneralInventoryController < ApplicationController

  def index
    location_id = session[:location]

    # Get drugs that have inventory
    drug_ids_with_stock = GeneralInventory
                           .where(voided: false, location_id: location_id)
                           .where('current_quantity > 0')
                           .distinct
                           .pluck(:drug_id)

    # Get aggregated data for each drug
    @inventory = GeneralInventory
                  .where(voided: false, location_id: location_id, drug_id: drug_ids_with_stock)
                  .joins(:drug => :drug_category)
                  .group('general_inventories.drug_id, drugs.name, drug_categories.category')
                  .select('general_inventories.drug_id, drugs.name AS drug_name, drug_categories.category AS drug_category_name, SUM(general_inventories.current_quantity) AS current_quantity')
  end

  def edit
    if request.post?
      # Edit a new record for general inventory
      @new_stock_entry = GeneralInventory.find_by_gn_identifier(params[:bottle_id])

      if @new_stock_entry.blank?
        flash[:errors] = "Item could not be found"
      else
        @new_stock_entry.expiration_date = params[:expiry_date].to_date rescue nil
        @new_stock_entry.received_quantity = params[:amount_received].to_i + (@new_stock_entry.received_quantity - @new_stock_entry.current_quantity)
        @new_stock_entry.current_quantity = params[:amount_received].to_i
        @new_stock_entry.location_id = session[:location]

        GeneralInventory.transaction do
          @new_stock_entry.save
        end

        if @new_stock_entry.errors.blank?
          flash[:success] = "#{@new_stock_entry.drug_name} (Bottle #: #{@new_stock_entry.gn_identifier}) was successfully updated."
        else
          flash[:errors] = @new_stock_entry.errors
        end
      end

      redirect_to "/" and return

    else
      # Handle GET request 
      @item = GeneralInventory.find_by(
        gn_inventory_id: params[:id],
        location_id: session[:location],
        voided: false
      )

      if @item.blank?
        flash[:errors] = "Item with ID #{params[:id]} not found in this location"
        redirect_to "/" and return
      end

      dispensary_loc = Location.find_by_name("Dispensary")&.id
      @is_dispensary = session[:location] == dispensary_loc
      render :layout => "touch"
    end
  end

def new
  dispensary_loc = Location.find_by_name("Dispensary")&.id
  @is_dispensary = session[:location] == dispensary_loc
  backstore_location = Location.find_by_name("Backstore")&.id || 5

  @dispensary_add_mode = params[:add_mode] == "true"

  # Load categories
  if @is_dispensary && !@dispensary_add_mode
    @available_categories = GeneralInventory
      .joins(drug: :drug_category)
      .where(location_id: backstore_location, voided: false)
      .where("current_quantity > 0")
      .select('drug_categories.drug_category_id, drug_categories.category')
      .distinct
      .map { |inv| { id: inv.drug_category_id, name: inv.category.strip } }
      .uniq { |c| c[:id] }
      .sort_by { |c| c[:name] }
  else
    @available_categories = DrugCategory.where(voided: false).order(:category)
      .map { |c| { id: c.drug_category_id, name: c.category.strip } }
  end

  # Get all drugs with their categories
  all_drugs = Drug.includes(:drug_category)
                  .where(voided: false)
                  .where.not(drug_category_id: nil)
                  .order(:name)

  # PROPER JSON maps
  @drug_to_category_map = {}
  all_drugs.each do |drug|
    next unless drug.name.present? && drug.drug_category_id.present?
    # Use lowercase for consistent searching
    @drug_to_category_map[drug.name.strip.downcase] = drug.drug_category_id
  end
  
  # Group drugs by category
  @category_to_drugs_map = {}
  all_drugs.each do |drug|
    next unless drug.drug_category_id.present?
    @category_to_drugs_map[drug.drug_category_id] ||= []
    @category_to_drugs_map[drug.drug_category_id] << drug.name.strip
  end

  # Sort drug names within each category
  @category_to_drugs_map.each do |category_id, drugs|
    drugs.uniq!  
    drugs.sort!  
  end


#Convert to JSON for JavaScript
  @drug_to_category_map_json = @drug_to_category_map.to_json
  @category_to_drugs_map_json = @category_to_drugs_map.to_json

  @category_to_name_map = DrugCategory.where(drug_category_id: @drug_to_category_map.values.uniq)  
                                   .pluck(:drug_category_id, :category)                          
                                   .to_h
  @category_to_name_map_json = @category_to_name_map.to_json



  render layout: "touch"
end

def create

    if params[:general_inventory] && params[:general_inventory][:amount_requested].present?
      additional_requested = if params[:general_inventory][:more_items].to_s.casecmp("Yes").zero?
                               params[:general_inventory][:number_of_items].to_i
                             else
                               0
                             end
      requested = params[:general_inventory][:amount_requested].to_i + additional_requested
      temp_drug_name = params[:general_inventory][:drug_name].to_s.strip
      temp_category_name = params[:general_inventory][:drug_category].to_s.strip

      # lookup to find drug - normalize strings for lookup
      # Check if temp_category_name is numeric (ID) or text (name)
      if temp_category_name.match?(/^\d+$/)
        # It's a category ID
        temp_drug = Drug.joins(:drug_category)
                  .where("TRIM(drugs.name) = ? AND drug_categories.drug_category_id = ?", temp_drug_name, temp_category_name.to_i)
                  .first
      else
        # It's a category name
        temp_drug = Drug.joins(:drug_category)
                  .where("TRIM(drugs.name) = ? AND TRIM(drug_categories.category) = ?", temp_drug_name, temp_category_name)
                  .first
      end

      if temp_drug
        backstore_id = Location.find_by_name("Backstore")&.id || 5
        available = GeneralInventory.where(drug_id: temp_drug.id, location_id: backstore_id, voided: false)
                                    .sum(:current_quantity).to_i

        if requested > available
          flash[:errors] = "You cannot request more than #{available} units."
          redirect_to new_general_inventory_path
          return
        end
      end
    end

    dispensary_loc = Location.find_by_name("Dispensary")&.id
    is_dispensary = session[:location] == dispensary_loc

    inventory_params = params[:general_inventory] || {}

    drug_name     = inventory_params[:drug_name].to_s.strip
    drug_category = inventory_params[:drug_category].to_s.strip

    # Backstore additions - normalize strings for lookup
    # Check if drug_category is numeric (ID) or text (name)
    if drug_category.match?(/^\d+$/)
      # It's a category ID
      drug = Drug.joins(:drug_category)
                .where(
                  "LOWER(TRIM(drugs.name)) = ? AND drug_categories.drug_category_id = ?",
                  drug_name.downcase,
                  drug_category.to_i
                )
                .first
    else
      # It's a category name
      drug = Drug.joins(:drug_category)
                .where(
                  "LOWER(TRIM(drugs.name)) = ? AND LOWER(TRIM(drug_categories.category)) = ?",
                  drug_name.downcase,
                  drug_category.downcase
                )
                .first
    end

    if drug.nil?
      Rails.logger.error "Drug not found - Name: '#{drug_name}', Category: '#{drug_category}' (stripped)"
      flash[:errors] = "The selected drug '#{drug_name}' could not be found in category '#{drug_category}'"
      redirect_to("/")
      return
    end

    drug_id = drug.drug_id
    drug_label = drug.name.presence || drug_name

    additional_qty = if inventory_params[:more_items].to_s.casecmp("Yes").zero?
                       inventory_params[:number_of_items].to_i
                     else
                       0
                     end

    mode = inventory_params[:mode] || 'request'

    if is_dispensary && mode == 'request'
      requested_qty = inventory_params[:amount_requested].to_s.strip.to_i

      if requested_qty <= 0
        flash[:errors] = "Quantity must be greater than 0"
        redirect_to "/" and return
      end

      total_qty = requested_qty + additional_qty

      # get oldest inventory entry from backstore to copy gn_identifier
      backstore_id = Location.find_by_name("Backstore")&.id || 5
      inventory_entry = GeneralInventory.where(drug_id: drug.id, location_id: backstore_id, voided: false)
                                        .order(:date_received)
                                        .first

      gn_identifier = inventory_entry&.gn_identifier

      begin
        Request.transaction do
          request = Request.new(
            drug_id:      drug_id,
            location_id:  session[:location],
            quantity:     total_qty,
            fulfilled:    false,
            gn_identifier: gn_identifier
          )

          unless request.save
            raise ActiveRecord::Rollback, request.errors.full_messages.join(", ")
          end
        end

        flash[:success] = "Request for #{drug_label} (total qty: #{total_qty}) submitted successfully."
        redirect_to "/" and return


      rescue => e
        flash[:errors] = "Failed to submit request: #{e.message}"
        redirect_to "/" and return
      end
    end

    # BACKSTORE flow: insert new general inventory entries
    received_qty = inventory_params[:amount_received].to_s.strip.to_i + additional_qty
    if received_qty <= 0
      flash[:errors] = "Quantity must be greater than 0"
      redirect_to "/" and return
    end

    expiry_date = begin
      inventory_params[:expiry_date].to_s.strip.presence&.to_date
    rescue
      nil
    end

    ids = []
    begin
      new_stock_entry = GeneralInventory.create!(
        drug_id:           drug_id,
        current_quantity:  received_qty,
        received_quantity: received_qty,
        expiration_date:   expiry_date,
        date_received:     Date.current,
        location_id:       session[:location],
      )
      ids << new_stock_entry.id
    rescue => e
      Rails.logger.error "Failed to create inventory entries: #{e.message}"
      flash[:errors] = "Failed to create inventory entries: #{e.message}"
      redirect_to "/" and return
    end

    if ids.empty?
      flash[:errors] = "No inventory entries were created"
      redirect_to "/" and return
    end

    if ids.length > 1
      flash[:success] = "#{ids.length} #{t('messages.items_of')} #{drug_label} #{t('messages.add_items_success')}."
      print_and_redirect("/general_inventory/print_bottle_barcode?ids=#{ids.join(',')}", "/")
    else
      flash[:success] = "#{drug_label} #{t('messages.add_item_success')}."
      print_and_redirect("/print_bottle_barcode/#{ids.first}", "/")
    end
  end

  def destroy
    #Delete an item from general inventory
    item = GeneralInventory.void_item(params[:id])
    if item.blank?
      flash[:errors]= "Item with bottle id #{params[:general_inventory][:gn_id]} could not be found"
    elsif item.errors.blank?
      flash[:success] = "#{item.drug_name} #{item.gn_identifier} was successfully deleted."
=begin
      news = News.where("refers_to = ? AND resolved = ?",
                        params[:general_inventory][:gn_id], false).first
      unless news.blank?
        news.resolved = true
        news.resolution = "Item was voided"
        news.date_resolved= Date.today
        news.save
      end
=end
    else
      flash[:errors] = item.errors
    end

    redirect_to "/general_inventory"
  end

  def print_bottle_barcode
    #This function prints bottle barcode labels for both inventory types
    if params[:ids].present?
      # Multiple bottles
      id_array = params[:ids].split(',').map(&:strip).map(&:to_i)
      entries = GeneralInventory.where(gn_inventory_id: id_array).to_a
      
      if entries.empty?
        render plain: "No bottles found", status: :not_found and return
      end
      
      print_string = ""
      entries.each do |bottle|
        print_string += "#{Misc.create_bottle_label(bottle.drug_name, bottle.gn_identifier, bottle.expiration_date)}\n"
      end
    elsif params[:id].present?
      # Single bottle
      entry = GeneralInventory.find_by(gn_inventory_id: params[:id])
      
      if entry.nil?
        render plain: "Bottle not found", status: :not_found and return
      end
      
      print_string = Misc.create_bottle_label(entry.drug_name, entry.gn_identifier, entry.expiration_date)
    else
      render plain: "No bottle ID provided", status: :bad_request and return
    end

    chars = ("a".."z").to_a  + ("0".."9").to_a
    rand_str = ""
    1.upto(7) { |i| rand_str << chars[rand(chars.size-1)] }
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{rand_str}.lbl", :disposition => "inline")
  end
   
  def ajax_bottle
    scanned = params[:id].to_s.strip

    # Determine context
    context =
      params[:context] ||
      (request.referer&.include?('/prepack_labels') ? 'prepacking' : 'patient')

    # Fix malformed PK codes
    if scanned =~ /\APK(G\d{7}-\d+)\z/i
      scanned = scanned.sub("PKG", "PK-G")
    end

    # Prepack scan label
    if scanned.start_with?("PK-")

      label = PrepackLabel.find_by(
        label_identifier: scanned,
        dispensed: 0,
        voided: 0,
        deleted: 0
      )

      return render json: { error: "This prepack has already been dispensed or is invalid" } if label.nil?

      prepack = label.prepack

      if context == "patient"

        bottle = GeneralInventory.find_by(
          gn_inventory_id: prepack.bottle_id,
          location_id: session[:location]
        )

        return render json: { error: "Bottle not found" } if bottle.nil?

        # Hard stop, expired
        if bottle.expiration_date.present? && bottle.expiration_date <= Date.current
          return render json: {
            error: "This bottle has expired and cannot be dispensed.",
            expired: true,
            expiration_date: bottle.expiration_date
          }, status: :unprocessable_entity
        end

        patient_id = params[:patient_id] || session[:patient_id]
        return render json: { error: "Patient context missing" } if patient_id.nil?

        disp = nil
        prescription = nil

        GeneralInventory.transaction do

          prescription = Prescription.create!(
            patient_id: patient_id,
            drug_id: bottle.drug_id,
            date_prescribed: Time.current,
            quantity: prepack.quantity_per_pack,
            amount_dispensed: prepack.quantity_per_pack,
            directions: prepack.directions || "Dispensed as prepack",
            provider_id: User.current.id
          )

          # Decrease bottle inventory quantity
          bottle.update!(current_quantity: bottle.current_quantity - prepack.quantity_per_pack)

          disp = Dispensation.create!(
            rx_id: prescription.id,
            inventory_id: bottle.gn_inventory_id,
            patient_id: patient_id,
            quantity: prepack.quantity_per_pack,
            dispensation_date: Time.current,
            dispensed_by: User.current.id,
            location_id: session[:location]
          )

          label.update!(
            dispensed: 1,
            patient_id: patient_id,
            dispensed_by: User.current.id,
            date_dispensed: Time.current
          )

          remaining_packs = prepack.prepack_labels.where(dispensed: [false, nil], deleted: 0, voided: 0).count

          prepack.update!(
            current_num_packs:  remaining_packs,
            status: (remaining_packs.zero? ? 'dispensed' : prepack.status),
            location_id: prepack.location_id || session[:location]
          )

        end

        return render json: {
          prepack: true,
          message: "Successfully dispensed #{bottle.drug.name}",
          quantity: prepack.quantity_per_pack,
          dispensation_id: disp.id,
          prescription_id: prescription.id,
          currentQty: bottle.current_quantity,
          currentNumPacks: prepack.current_num_packs
        }
      end

      # Prepacking mode, No dispensing
      return render json: {
        prepack: true,
        drug_id: prepack.bottle_id,
        quantity_per_pack: prepack.quantity_per_pack,
        label: label.label_identifier
      }
    end

    # Regular bottle scan
    # Find the best available entry
    entries = GeneralInventory.includes(:drug).where(
      gn_identifier: scanned,
      location_id: session[:location],
      voided: false
    ).where('current_quantity > 0')

    if entries.empty?
      # Check if there are any entries at all
      any_entry = GeneralInventory.includes(:drug).find_by(
        gn_identifier: scanned,
        location_id: session[:location],
        voided: false
      )
      
      if any_entry.nil?
        return render json: {
          error: "Bottle not found"
        }, status: :not_found
      else
        return render json: {
          error: "This bottle is out of stock",
          name: any_entry.drug.name,
          currentQty: 0
        }, status: :unprocessable_entity
      end
    end

    # Get the entry with earliest expiration date that has stock
    entry = entries.order(:expiration_date, :gn_inventory_id).first

    # Calculate total available quantity across all sequences
    total_quantity = entries.sum(:current_quantity)

    # Hard stop, expired
    if entry.expiration_date.present? && entry.expiration_date <= Date.current
      return render json: {
        error: "This bottle has expired and cannot be used.",
        expired: true,
        expiration_date: entry.expiration_date
      }, status: :unprocessable_entity
    end

    has_active_prepacks = PrepackLabel
                            .where(bottle_id: entry.gn_inventory_id, dispensed: 0)
                            .exists?

    render json: {
      name: entry.drug.name,
      currentQty: total_quantity,
      prepack: has_active_prepacks
    }
  end

  def show
    @item = GeneralInventory.find_by(
      gn_identifier: params[:id].to_s,
      gn_sequence: params[:sequence].to_s,
      location_id: session[:location]
    )

    if @item.blank?
      flash[:errors] = "Item with ID #{params[:id]} sequence #{params[:sequence]} not found in this location"
      redirect_to "/" and return
    end
    # Load all transaction records for this inventory item at this location
    @records = Issue.where(inventory_id: @item.gn_inventory_id).order(issue_date: :desc)
  end

  def list
    @drug = Drug.find_by_drug_id(params[:drug_id])
    @inventory = GeneralInventory.where("current_quantity > ? and drug_id = ? and location_id = ? and voided = ?",
                                        0, params[:drug_id] ,session[:location], false)
  end

  def prepack_labels

    render :prepack_labels
  end

  def pre_packing
    GeneralInventory.transaction do
      @item = GeneralInventory.where("gn_identifier = ? ", params[:bottle_id]).lock(true).first
      @item.current_quantity = @item.current_quantity.to_i - params[:pre_pack_amount].to_i
      @item.received_quantity = @item.received_quantity.to_i - params[:pre_pack_amount].to_i
      @item.save

      if @item.errors.blank?
        @new_stock_entry = GeneralInventory.new
        @new_stock_entry.drug_id = @item.drug_id
        @new_stock_entry.current_quantity = params[:pre_pack_amount]
        @new_stock_entry.expiration_date = @item.expiration_date
        @new_stock_entry.received_quantity = params[:pre_pack_amount]
        @new_stock_entry.date_received = Date.current
        @new_stock_entry.location_id = @item.location_id
        @new_stock_entry.save

        if @new_stock_entry.errors.blank?
          flash[:success] = "#{params[:bottle_id]} was successfully issued."
          print_and_redirect("/general_inventory/print_pre_packed/#{@new_stock_entry.id}", "/general_inventory/#{@item.gn_identifier}")
        else
          flash[:errors] = "Insufficient stock on hand"
          redirect_to "/general_inventory/#{@item.gn_identifier}" and return
        end
      end
    end
  end

  def merge
    bottles = GeneralInventory.where(gn_inventory_id: params[:bottle_ids].split(','))
    quantity = 0
    GeneralInventory.transaction do
      (bottles || []).each do |bottle|
        quantity += bottle.current_quantity.to_i
        bottle.received_quantity = bottle.received_quantity.to_i - bottle.current_quantity.to_i
        bottle.current_quantity = 0
        bottle.save
      end

      item = bottles.first

      @new_stock_entry = GeneralInventory.new
      @new_stock_entry.drug_id = item.drug_id
      @new_stock_entry.current_quantity = quantity
      @new_stock_entry.expiration_date = item.expiration_date
      @new_stock_entry.received_quantity = quantity
      @new_stock_entry.date_received = Date.current
      @new_stock_entry.location_id = item.location_id
      @new_stock_entry.save

      if @new_stock_entry.errors.blank?
        flash[:success] = "Items were successfully merged."
        print_and_redirect("/print_bottle_barcode/#{@new_stock_entry.id}", "/general_inventory/list?drug_id=#{item.drug_id}")
      else
        flash[:errors] = "Items could not be merged"
        redirect_to "/general_inventory/#{@new_stock_entry.gn_identifier}" and return
      end
    end
  end

  def print_pre_packed
    #This function prints bottle barcode labels for both inventory types
    id = params[:ids].split(',') rescue params[:id]
    entry = GeneralInventory.find(id)
    if entry.is_a?(Array)
      print_string = ""
      (entry || []).each do |bottle|
        print_string += "#{Misc.create_bottle_label(bottle.drug_name,bottle.gn_identifier,bottle.expiration_date,bottle.received_quantity)}\n"
      end
    else
      print_string = Misc.create_bottle_label(entry.drug_name,entry.gn_identifier,entry.expiration_date, entry.received_quantity)
    end

    chars = ("a".."z").to_a  + ("0".."9").to_a
    rand_str = ""
    1.upto(7) { |i| rand_str << chars[rand(chars.size-1)] }
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{rand_str}.lbl", :disposition => "inline")
  end

  def damage_item
    damage_type = params[:damage_type].to_s.downcase
    prepack_id = params[:prepack_id]

    if prepack_id.present?
      # We're dealing with prepack damage (either pack or bottle damage from prepack page)
      prepack = Prepack.find_by(
        id: prepack_id,
        location_id: session[:location] || User.current.location_id,
        voided: 0,
        deleted: 0
      )

      unless prepack
        render json: { success: false, message: "Prepack not found" }, status: 404 and return
      end

      active_pack_count = PrepackLabel.where(
        prepack_id: prepack.id,
        voided: 0,
        deleted: 0,
      ).where(dispensed: [false, nil]).count

      if active_pack_count <= 0
        render json: {
          success: false,
          message: "Only active packs can be marked as damaged"
        }, status: :forbidden and return
      end

      # Load the general inventory via the prepack
      item = GeneralInventory.find_by(gn_identifier: prepack.gn_identifier)
      unless item
        render json: { success: false, message: "Inventory item not found" }, status: 404 and return
      end
    else
      # Regular bottle damage from general inventory page
      item = GeneralInventory.find_by(gn_inventory_id: params[:id])
      unless item
        render json: { success: false, message: "Inventory item not found" }, status: 404 and return
      end
      prepack = nil
    end

    qty = params[:quantity].to_i
    reason = params[:reason].to_s.strip
    if qty <= 0
      render json: { success: false, message: "Quantity must be greater than zero" } and return
    end

    ActiveRecord::Base.transaction do
      if damage_type == "pack" && prepack.present?
        # Pack damage - void prepack labels
        labels = PrepackLabel.where(prepack_id: prepack.id, voided: 0, deleted: 0, dispensed: 0)
                              .order(:id).limit(qty)

        if labels.count < qty
          render json: { success: false, message: "Not enough unvoided packs available" } and return
        end

        labels.update_all(voided: 1, updated_at: Time.current)
        total_units_lost = prepack.quantity_per_pack * qty
        remaining_packs = prepack.prepack_labels.where(dispensed: [false, nil], deleted: false, voided: false).count
        prepack.update!(current_num_packs: remaining_packs,
                        total_quantity: prepack.total_quantity - total_units_lost)
      else
        # Bottle damage - reduce inventory quantity
        if qty > item.current_quantity
          render json: { success: false, message: "Quantity exceeds available stock" } and return
        end

        item.update!(current_quantity: item.current_quantity - qty)
      end

      damage_params = {
        general_inventory_id: item.gn_inventory_id,
        gn_identifier: item.gn_identifier,
        quantity: qty,
        reason: reason,
        reported_by: User.current.id,
        location_id: session[:location] || User.current.location_id,
        damage_date: Time.current,
        damage_type: damage_type
      }
      damage_params[:prepack_id] = prepack.id if damage_type == "pack"

      Damage.create!(damage_params)
    end

    render json: { success: true }

  rescue => e
    Rails.logger.error "Damage reporting failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: "Failed to record damage: #{e.message}" }, status: 500
  end

end
