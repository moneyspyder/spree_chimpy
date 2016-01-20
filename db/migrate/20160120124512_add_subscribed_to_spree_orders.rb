class AddSubscribedToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :subscribed, :boolean, default: true, index: true
  end
end
