class Request < ActiveRecord::Base
  belongs_to :drug
  belongs_to :location, optional: true
  belongs_to :fulfilled_by_user, class_name: "User", foreign_key: :fulfilled_by, optional: true

  validates :drug_id, :location_id, :quantity, presence: true
  validates :quantity, numericality: { greater_than: 0 }

  # Increment quantity_received
  def receive_issue!(amount, user_id)
    self.with_lock do
      self.quantity_received ||= 0
      self.quantity_received += amount

      if self.quantity_received >= self.quantity
        self.fulfilled = true
        self.fulfilled_at = Time.current
        self.fulfilled_by = user_id
      end

      save!
    end
  end

def quantity_remaining
    [quantity - (quantity_received || 0), 0].max
  end
end