class MobileVisitProductController < ApplicationController
  def index

  end

  def new

  end

  def show

  end

  def create

      GeneralInventory.transaction do
        item = GeneralInventory.where("gn_identifier = ? ", params[:bottle_id]).lock(true).first
        item.current_quantity = item.current_quantity.to_i - params[:amount].to_i
        item.save

        if item.errors.blank?
          new_mobile_visit_product = MobileVisitProduct.create({:mobile_visit_id => params[:visit_id],
                                                                :amount_used => params[:amount].to_i,
                                                                :amount_taken => params[:amount].to_i,
                                                                :gn_identifier => params[:bottle_id] })
        else
          flash[:errors] = "Insufficient stock on hand"
        end

      end
    redirect_to "/mobile_visit/#{params[:visit_id]}" and return
  end

  def edit

  end

  def update
    products = MobileVisitProduct.where("voided = ? and mvp_id = ?", false, params[:mvp_id])
    MobileVisitProduct.transaction do

      (products || []).each do |product|

        product.update_attributes(:amount_used => (product.amount_taken - params[:amount].to_i))
        item = GeneralInventory.where("gn_identifier = ? AND voided = ?", product.gn_identifier, false).first

        next if item.blank?

        item.current_quantity += params[:amount].to_i
        item.save

      end
    end

    redirect_to "/mobile_visit/#{products.first.mobile_visit_id}"and return

  end

  def destroy
    products = MobileVisitProduct.where("voided = ? and mvp_id = ?", false, params[:id])

    MobileVisitProduct.transaction do

      (products || []).each do |product|

        product.update_attributes(:voided => true)
        item = GeneralInventory.where("gn_identifier = ? AND voided = ?", product.gn_identifier, false).first

        next if item.blank?

        item.current_quantity =  item.current_quantity + product.amount_taken
        item.save

      end
    end

    redirect_to "/mobile_visit/#{products.first.mobile_visit_id}"and return
  end
end
