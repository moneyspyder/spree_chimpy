class AddSubscriptionSentToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :subscription_sent_at, :datetime, index: true
  end
end
