class IssuesController < ApplicationController
  def new
    @bottle = params[:bottle]
    render layout: 'touch'
  end

  def edit

  end

  def create
    GeneralInventory.transaction do
      @item = GeneralInventory.where("gn_identifier = ? ", params[:bottle_id]).lock(true).first
      @item.current_quantity = @item.current_quantity.to_i - params[:amount_issued].to_i
      @item.save

      if @item.errors.blank?
        @new_stock_entry = GeneralInventory.new
        @new_stock_entry.drug_id = @item.drug_id
        @new_stock_entry.current_quantity = params[:amount_issued]
        @new_stock_entry.expiration_date = @item.expiration_date
        @new_stock_entry.received_quantity = params[:amount_issued]
        @new_stock_entry.date_received = Date.current
        @new_stock_entry.location_id = Location.find_by_name(params[:location]).id
        @new_stock_entry.save

        new_issue = Issue.create( inventory_id: @item.id, location_id: session[:location],
                                  issued_to: @new_stock_entry.location_id, issued_by: session[:user_id],
                                  quantity: params[:amount_issued], issue_date: DateTime.current)

        if @new_stock_entry.errors.blank?
          flash[:success] = "#{params[:bottle_id]} was successfully issued."
          print_and_redirect("/print_bottle_barcode/#{@new_stock_entry.id}", "/general_inventory/#{@item.gn_identifier}")
        else
          flash[:errors] = "Insufficient stock on hand"
          redirect_to "/general_inventory/#{@item.gn_identifier}" and return
        end
      end
    end
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
