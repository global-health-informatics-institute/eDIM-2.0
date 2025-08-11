class MobileVisitProduct < ActiveRecord::Base
  belongs_to :mobile_visit, :foreign_key => :mobile_visit_id

  def voidable
    if self.amount_taken != self.amount_used
      return false
    elsif self.created_at != self.updated_at
      return false
    else
      return true
    end
  end
end
