class GeneralInventoryController < ApplicationController

  def index
    @inventory = GeneralInventory.select("drug_id, sum(current_quantity) as current_quantity").where(
                                          "location_id = ? and voided = ?",session[:location], false).group('drug_id').having("current_quantity > 0")
  end

  def new
    render :layout => "touch"
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
      @item = GeneralInventory.find(params[:id])
      render :layout => "touch"
    end
  end

  def create

    # Create a new record for general inventory
    #raise params.inspect
    count = params['number_of_items'].to_i rescue 0
    drug_id = Drug.find_by_name(params[:drug_name]).id rescue nil

    if drug_id.blank?
      flash[:errors] = "Item #{params[:drug_name]} was not found"
      redirect_to "/" and return
    else
      ids = []

      GeneralInventory.transaction do
        (0..count).each do |i|
          @new_stock_entry = GeneralInventory.new
          @new_stock_entry.drug_id = drug_id
          @new_stock_entry.current_quantity = params[:amount_received]
          @new_stock_entry.expiration_date = params[:expiry_date].to_date rescue nil
          @new_stock_entry.received_quantity = params[:amount_received]
          @new_stock_entry.date_received = Date.current
          @new_stock_entry.location_id = session[:location]
          @new_stock_entry.save

          if @new_stock_entry.errors.blank?
            ids << @new_stock_entry.id
          else
            flash[:errors] = @new_stock_entry.errors.join(",")
            redirect_to "/" and return
          end
        end
      end

      if ids.length > 1
        flash[:success] = "#{ids.length} #{t('messages.items_of')} #{params[:drug_name]} #{t('messages.add_items_success')}."
        print_and_redirect("/general_inventory/print_bottle_barcode?ids=#{ids.join(',')}", "/")
      else
        flash[:success] = "#{params[:drug_name]} #{t('messages.add_item_success')}."
        print_and_redirect("/print_bottle_barcode/#{ids.first}", "/")
      end
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
    id = params[:ids].split(',') rescue params[:id]
    entry = GeneralInventory.find(id)
#    raise params[:id].inspect
    if entry.is_a?(Array)
      print_string = ""
      (entry || []).each do |bottle|
        print_string += "#{Misc.create_bottle_label(bottle.drug_name,bottle.gn_identifier,bottle.expiration_date)}\n"
      end
    else
      print_string = Misc.create_bottle_label(entry.drug_name,entry.gn_identifier,entry.expiration_date)
    end

    chars = ("a".."z").to_a  + ("0".."9").to_a
    rand_str = ""
    1.upto(7) { |i| rand_str << chars[rand(chars.size-1)] }
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{rand_str}.lbl", :disposition => "inline")
  end

  def ajax_bottle
    entry = GeneralInventory.find_by_gn_identifier(params[:id])
    if entry.blank?
      render :text => ''
    else
      render :text => {"name" => entry.drug_name, "currentQty"=> entry.current_quantity}.to_json
    end

  end

  def show
    @item = GeneralInventory.find_by_gn_identifier_and_location_id(params[:id].to_s,session[:location])
    if @item.blank?
      flash[:errors] = "Item with ID #{params[:id]} not found at this location"
      redirect_to "/" and return
    end

    if Location.find(session[:location]).name.match(/store/i)
      @records = Issue.where(inventory_id: @item.gn_inventory_id)
    end
  end

  def list
    @drug = Drug.find_by_drug_id(params[:drug_id])
    @inventory = GeneralInventory.where("current_quantity > ? and drug_id = ? and location_id = ? and voided = ?",
                                        0, params[:drug_id] ,session[:location], false)
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
#    raise params[:id].inspect
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
end
