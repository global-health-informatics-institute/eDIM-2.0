class MobileVisitController < ApplicationController

  def index
    @visits = MobileVisit.where("voided = ? ", false).order(visit_date: :desc)
  end

  def new
    render :layout => "touch"
  end

  def show
    @visit = MobileVisit.find(params[:id])
    @visit_products = view_context.list_products(MobileVisitProduct.where("voided = ? and mobile_visit_id = ?",false,params[:id]))
  end

  def create

    coordinator = User.select("user_id , CONCAT(COALESCE(first_name,''),COALESCE(middle_name,''),
                                COALESCE(fathers_name,''),COALESCE(mothers_name,'')) as username").where("voided =?", false, ).having("username = ?", params[:visit_coordinator].gsub(" ","")).first rescue nil

    @new_visit = MobileVisit.where(visit_date: params[:visit_date].to_date, visit_supervisor: coordinator.id,voided: false).first_or_initialize

    @new_visit.save if @new_visit.id.blank?

    if @new_visit.errors.blank?
      redirect_to "/mobile_visit/#{@new_visit.id}" and return
    else
      flash[:errors] = "Mobile visit could not be created"
      redirect_to "/mobile_visit" and return
    end
  end

  def edit
    @visit = MobileVisit.find(params[:id])
    @coordinators = User.where("voided = ? AND role in (?)", false, ["administrator","Pharmacist"]).collect{|x|[x.id,x.fullname]}
    render :layout => "touch"
  end

  def update
    @new_visit = MobileVisit.find(params[:id])
    @new_visit.update_attributes(visit_date: params[:visit_date].to_date, visit_supervisor: params[:visit_coordinator].to_i)
    redirect_to "/mobile_visit" and return
  end

  def destroy
    void_visit = MobileVisit.find(params[:id])

    MobileVisit.transaction do

      void_visit.update_attributes(:voided => true)

      products = MobileVisitProduct.where("voided = ? and mobile_visit_id = ?", false, void_visit.id)

      (products || []).each do |product|

        product.voided = true
        product.save

        item = GeneralInventory.where("gn_identifier = ? AND voided = ?", product.gn_identifier, false).first

        next if item.blank?

        item.current_quantity += product.amount_used
        item.save

      end
    end

    redirect_to "/mobile_visit" and return
  end
end
