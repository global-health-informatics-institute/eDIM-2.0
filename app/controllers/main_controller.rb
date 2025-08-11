class MainController < ApplicationController
  def index
  end

  def settings
  end

  def select_report
    case params[:type]
      when 'prescription'
        @path = '/main/prescription_report'
      when 'dispensation'
        @path = '/main/dispensation_report'
      when 'storeroom'
        @path = '/main/stores_report'
        locations = GeneralInventory.where(gn_inventory_id: Issue.all.pluck(:inventory_id)).pluck(:location_id)
        @locations = ['All Locations'] + Location.where(location_id: locations.uniq).pluck(:name)
    end
    render :layout => "touch"
  end

  def dispensation_report
    case params[:report_duration]
      when t('forms.options.daily')
        @report_type = "#{t('menu.terms.daily_report')} #{l(params[:start_date].to_date, format:'%d %B, %Y')}"
        start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.weekly')
        @report_type = "#{t('menu.terms.weekly_report')} #{l(params[:start_date].to_date.beginning_of_week, format:'%d %B, %Y')}
                        #{t('menu.terms.to')} #{l(params[:start_date].to_date.end_of_week, format: '%d %B, %Y')}"

        start_date = params[:start_date].to_date.beginning_of_week.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.end_of_week.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.monthly')
        @report_type = "#{t('menu.terms.monthly_report')} #{l(params[:start_date].to_date, format: '%B %Y')}"
        start_date = params[:start_date].to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')
      when t('forms.options.range')
        @report_type = "#{t('menu.terms.custom_report')} #{l(params[:start_date].to_date, format: '%d %B, %Y')}
                        #{t('menu.terms.to')} #{l(params[:end_date].to_date, format: '%d %B, %Y')}"
        start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')
    end

    dispensations = Dispensation.find_by_sql("SELECT sum(d.quantity) as quantity,g.drug_id FROM `dispensations` d left
                                              outer join general_inventories g on d.inventory_id = g.gn_identifier
                                              where d.voided = 0 and g.drug_id is not null and dispensation_date BETWEEN
                                              '#{start_date}' and '#{end_date}' GROUP BY g.drug_id")

    inventory = GeneralInventory.select("SUM(current_quantity) as current_quantity, drug_id").where("voided = ? and
                                         date_received <= ?", false, end_date.to_date.strftime("%Y-%m-%d")).group("drug_id")


    later_dispensations = Dispensation.find_by_sql("SELECT sum(d.quantity) as quantity,g.drug_id FROM `dispensations` d left
                                              outer join general_inventories g on d.inventory_id = g.gn_identifier
                                              where d.voided = 0 and g.drug_id is not null and dispensation_date > '#{end_date}'
                                              and g.date_received <= '#{end_date.to_date.strftime("%Y-%m-%d")}'
                                              GROUP BY g.drug_id")

    @items = view_context.compile_report(dispensations,inventory,later_dispensations)

  end


  def prescription_report
    case params[:report_duration]
      when t('forms.options.daily')
        @report_type = "Daily prescription report for #{l(params[:start_date].to_date, format:'%d %B, %Y')}"
        start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.weekly')
        @report_type = "Weekly prescription report from #{l(params[:start_date].to_date.beginning_of_week, format:'%d %B, %Y')}
        #{t('menu.terms.to')} #{l(params[:start_date].to_date.end_of_week, format: '%d %B, %Y')}"

        start_date = params[:start_date].to_date.beginning_of_week.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.end_of_week.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.monthly')
        @report_type = "Monthly prescription report for #{l(params[:start_date].to_date, format: '%B %Y')}"
        start_date = params[:start_date].to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:start_date].to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')
      when t('forms.options.range')
        @report_type = "Prescription report from #{l(params[:start_date].to_date, format: '%d %B, %Y')}
        #{t('menu.terms.to')} #{l(params[:end_date].to_date, format: '%d %B, %Y')}"
        start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
        end_date = params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')
    end

    @items = []

  end

  def stores_report
    @report_type,start_date,end_date = resolve_durations(params[:report_duration],'Stores Report',params[:start_date],params[:end_date])

    if params[:locations].include? 'All Locations'
      issued = Issue.all.pluck(:inventory_id)
      if issued.blank?
        locations = GeneralInventory.all.pluck(:location_id).uniq.join(',') rescue []
      else
        locations = GeneralInventory.where(gn_inventory_id: issued).pluck(:location_id).uniq.join(',') rescue []
      end
    else
      locations = Location.where(name: params[:locations]).pluck(:location_id).join(',')
    end

    receipts = GeneralInventory.select('drug_id,
                                        SUM(received_quantity) as received_quantity'
                                      ).where('voided = ? and location_id in (?) and date_received BETWEEN ? AND ?',
                                              false,locations,start_date.to_date.strftime('%Y-%m-%d'),
                                              end_date.to_date.strftime('%Y-%m-%d')).group('drug_id') rescue []

    unless locations.blank?
      issues = Issue.select(:inventory_id,:quantity).where("issue_date BETWEEN '#{start_date}' and '#{end_date}'
                              and location_id in (#{(locations)}) and voided = false") rescue []

      later_issues = Issue.select(:inventory_id,:quantity).where("issue_date > '#{end_date}' and
                                                                location_id in (#{locations}) and voided = false") rescue []

    end

    current_stock = GeneralInventory.select('SUM(current_quantity) as current_quantity,
                                            drug_id').where('voided = ? and date_received <= ? and location_id in (?)',
                                                            false, end_date.to_date.strftime('%Y-%m-%d'),locations
                                                            ).group("drug_id") rescue []

    #getting drug ids for the issued items
    issue_ids = (issues.collect { |x| x.inventory_id } + later_issues.collect { |x| x.inventory_id }).uniq rescue []
    drug_map = Hash[*GeneralInventory.where('gn_inventory_id in (?) AND date_received <= ?',issue_ids,
                                            end_date.to_date.strftime('%Y-%m-%d')).pluck(:gn_inventory_id, :drug_id).flatten(1)]

    @records = view_context.stores_report(issues,receipts,current_stock,later_issues,drug_map)
  end

  def time
    render :text => Time.current().strftime('%Y-%m-%d %H:%M').to_s
  end

  private

  def resolve_durations(report_type,report_title,start_date,end_date)
    case report_type
      when t('forms.options.daily')
        report_title = "#{report_title} #{l(start_date.to_date, format:'%d %B, %Y')}"
        starting_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
        ending_date = start_date.to_date.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.weekly')
        report_title = "#{report_title} #{l(start_date.to_date.beginning_of_week, format:'%d %B, %Y')}
        #{t('menu.terms.to')} #{l(start_date.to_date.end_of_week, format: '%d %B, %Y')}"

        starting_date = start_date.to_date.beginning_of_week.strftime('%Y-%m-%d 00:00:00')
        ending_date = start_date.to_date.end_of_week.strftime('%Y-%m-%d 23:59:59')

      when t('forms.options.monthly')
        report_title = "#{report_title} #{l(start_date.to_date, format: '%B %Y')}"
        starting_date = start_date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00')
        ending_date = start_date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')
      when t('forms.options.range')
        report_title = "#{report_title} #{l(start_date.to_date, format: '%d %B, %Y')}
        #{t('menu.terms.to')} #{l(end_date.to_date, format: '%d %B, %Y')}"
        starting_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
        ending_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    end
    return report_title, starting_date, ending_date
  end
end
