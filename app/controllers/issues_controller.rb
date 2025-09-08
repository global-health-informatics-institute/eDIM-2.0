class IssuesController < ApplicationController

  def new
    @locations = Location.where.not(location_id: session[:location])
    @drug_id = params[:drug_id]
    @request_id = params[:request_id]

    # Prefill amount if this is a requested issue
    if @request_id.present?
      request = Request.find_by(id: @request_id)
      @prefill_amount = request&.quantity
    else
      @prefill_amount = nil
    end

    render layout: 'touch'
  end


  def create
    request = Request.find(params[:request_id])
    issued_quantity = params[:amount_issued].to_i
    target_location = Location.find_by(name: params[:location])

    source_stock = GeneralInventory.find_by(
      gn_identifier: request.gn_identifier,
      location_id: 5,  # Backstore
      drug_id: request.drug_id
    )

    if source_stock.nil? || source_stock.current_quantity < issued_quantity
      flash[:errors] = "Insufficient stock in Backstore for #{request.drug.name}"
      redirect_to "/issues/new?drug_id=#{request.drug_id}&request_id=#{request.id}" and return
    end

    dest_stock = nil  # define here

    ActiveRecord::Base.transaction do
      # Deduct from Backstore
      source_stock.update!(current_quantity: source_stock.current_quantity - issued_quantity)

      # Add to destination (same bottle, target location)
      dest_stock = GeneralInventory.find_or_initialize_by(
        gn_identifier: source_stock.gn_identifier,
        location_id: target_location.id,
        drug_id: source_stock.drug_id
      )
      dest_stock.received_quantity ||= 0
      dest_stock.current_quantity ||= 0
      dest_stock.received_quantity += issued_quantity
      dest_stock.current_quantity += issued_quantity
      dest_stock.expiration_date ||= source_stock.expiration_date
      dest_stock.date_received ||= Date.current
      dest_stock.save!

      # Create issue record
      Issue.create!(
        inventory_id: source_stock.id,
        location_id: source_stock.location_id,
        issued_to: dest_stock.location_id,
        issued_by: session[:user_id],
        quantity: issued_quantity,
        issue_date: DateTime.current
      )

      # Mark request as fulfilled
      request.update!(
        gn_identifier: source_stock.gn_identifier,
        fulfilled: true,
        fulfilled_at: DateTime.current,
        fulfilled_by: session[:user_id]
      )
    end

    flash[:success] = "#{issued_quantity} units of #{request.drug.name} issued successfully."
    print_and_redirect("/print_bottle_barcode/#{dest_stock.id}", "/requests")
  rescue => e
    flash[:errors] = "Error issuing stock: #{e.message}"
    redirect_to "/issues/new?drug_id=#{request.drug_id}&request_id=#{request.id}"
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