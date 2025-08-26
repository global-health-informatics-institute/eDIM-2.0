class IssuesController < ApplicationController
  def new
    @bottle = params[:bottle]
    @locations = Location.where.not(location_id: session[:location])
    render layout: 'touch'
  end

  def create
    GeneralInventory.transaction do
      # 1. Find source stock (backstore) and lock it
      source_stock = GeneralInventory.where(
        gn_identifier: params[:bottle_id],
        location_id: session[:location]
      ).lock(true).first

      issued_quantity = params[:amount_issued].to_i

      if source_stock.nil? || source_stock.current_quantity < issued_quantity
        flash[:errors] = "Insufficient stock in source location"
        redirect_to "/general_inventory/#{params[:bottle_id]}" and return
      end

      # 2. Reduce backstore
      source_stock.update!(current_quantity: source_stock.current_quantity - issued_quantity)

      # 3. Find or create destination stock (same bottle, target location)
      destination_stock = GeneralInventory.find_or_initialize_by(
        gn_identifier: source_stock.gn_identifier,
        location_id: Location.find_by(name: params[:location]).id,
        drug_id: source_stock.drug_id
      )
      destination_stock.received_quantity ||= 0
      destination_stock.current_quantity ||= 0
      destination_stock.received_quantity += issued_quantity
      destination_stock.current_quantity += issued_quantity
      destination_stock.expiration_date ||= source_stock.expiration_date
      destination_stock.date_received ||= Date.current
      destination_stock.save!

      # 4. Create Issue record linking source and destination
      Issue.create!(
        inventory_id: source_stock.id,
        location_id: source_stock.location_id,
        issued_to: destination_stock.location_id,
        issued_by: session[:user_id],
        quantity: issued_quantity,
        issue_date: DateTime.current
      )

      flash[:success] = "#{source_stock.gn_identifier} was successfully issued."
      print_and_redirect("/print_bottle_barcode/#{destination_stock.id}", "/general_inventory/#{source_stock.gn_identifier}")
    end
  rescue => e
    flash[:errors] = "Error issuing stock: #{e.message}"
    redirect_to "/general_inventory/#{params[:bottle_id]}"
  end

  def update

  end

  def show

  end

  def list
    case params[:report_duration]
      when t('forms.options.daily')
        @report_type = "Issues Report for #{l(params[:start_date].to_date, format:'%d %B, %Y')}"
        start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.weekly')
        @report_type = "Issues Report from #{l(params[:start_date].to_date.beginning_of_week, format:'%d %B, %Y')}
        #{t('menu.terms.to')} #{l(params[:start_date].to_date.end_of_week, format: '%d %B, %Y')}"

        start_date = params[:start_date].to_date.beginning_of_week.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.end_of_week.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.monthly')
        @report_type = "Issues Report for #{l(params[:start_date].to_date, format: '%B %Y')}"
        start_date = params[:start_date].to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')
      when t('forms.options.range')
        @report_type = "Issues Report from #{l(params[:start_date].to_date, format: '%d %B, %Y')}
        #{t('menu.terms.to')} #{l(params[:end_date].to_date, format: '%d %B, %Y')}"
        start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')
    end

    if params[:locations].include? 'All Locations'
      @records = Issue.where("issue_date BETWEEN '#{start_date}' and '#{end_date}' and voided = false")
    else
      locations = Location.where(name: params[:locations]).pluck(:location_id).join(',')
      @records = Issue.where("issue_date BETWEEN '#{start_date}' and '#{end_date}'
                              and location_id in (#{locations}) and voided = false")
    end
  end

  def select
    locations = GeneralInventory.where(gn_inventory_id: Issue.all.pluck(:inventory_id)).pluck(:location_id)
    @locations = ['All Locations'] + Location.where(location_id: locations.uniq).pluck(:name)
    render layout: 'touch'
  end
end
