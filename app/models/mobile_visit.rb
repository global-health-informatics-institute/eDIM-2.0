class MobileVisit < ActiveRecord::Base

  has_many :mobile_visit_products
  belongs_to :user, :foreign_key => :visit_supervisor

  validates_presence_of :visit_date
  validates_presence_of :visit_supervisor

  def coordinator
      self.user.display_name
  end

  def products
    products = MobileVisitProduct.where("voided = ? and mobile_visit_id = ?", false, self.id).length
  end
end
