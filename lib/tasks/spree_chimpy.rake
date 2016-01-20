namespace :spree_chimpy do
  namespace :merge_vars do
    desc 'sync merge vars with mail chimp'
    task :sync do
      Spree::Chimpy.sync_merge_vars
    end
  end

  namespace :subscribers do
    desc 'send subscribers to mail chimp'
    task sync: :environment do
      subscribers = Spree::Chimpy::Subscriber.where(subscribed: nil)

      puts "Exporting #{subscribers.count} subscribers"

      subscribers.each do |subscriber|
        subscriber.subscribed = true
        subscriber.save
      end
    end
  end

  namespace :orders do
    desc 'sync all orders with mail chimp'
    task sync: :environment do
      scope = Spree::Order.complete

      puts "Exporting #{scope.count} orders"

      scope.find_in_batches do |batch|
        print '.'
        batch.each do |order|
          begin
            order.notify_mail_chimp
          rescue => exception
            if defined?(::Delayed::Job)
              raise exception
            else
              puts exception
            end
          end
        end
      end

      puts nil, 'done'
    end

    desc 'send new signups sync their orders with mail chimp'
    task sync_new: :environment do
      scope = Spree::Order.complete.where(subscription_sent_at: nil)

      puts "Exporting #{scope.count} orders"

      scope.find_in_batches do |batch|
        print '.'
        batch.each do |order|

          begin
            if order.subscribed
              if order.user
                payload = {class: order.user.class.name, id: order.user.id, object: order.user}
              else
                payload = {class: order.class.name, id: order.id, object: order}
              end
              payload[:event] = :subscribe
              Spree::Chimpy.perform(payload)
              order.subscription_sent_at = DateTime.now
              order.save
            end

            payload = {class: order.class.name, id: order.id, object: order}
            payload[:event] = :order
            Spree::Chimpy.perform(payload)

          rescue => exception
            if defined?(::Delayed::Job)
              raise exception
            else
              puts exception
            end
          end
        end
      end

      puts nil, 'done'
    end
  end

  namespace :users do
    desc 'segment all subscribed users'
    task segment: :environment do
      if Spree::Chimpy.segment_exists?
        emails = Spree.user_class.where(subscribed: true).pluck(:email)
        puts "Segmenting all subscribed users"
        response = Spree::Chimpy.list.segment(emails)
        response["errors"].try :each do |error|
          puts "Error #{error["code"]} with email: #{error["email"]} \n msg: #{error["msg"]}"
        end
        puts "segmented #{response["success"] || 0} out of #{emails.size}"
        puts "done"
      end
    end
  end

  desc 'sync all users with mailchimp'
  task sync: :environment do
    emails = Spree.user_class.pluck(:email)
    puts "Syncing all users"
    emails.each do |email|
      response = Spree::Chimpy.list.info(email)
      print '.'

      response["errors"].try :each do |error|
        puts "Error #{error['error']["code"]} with email: #{error['email']["email"]} \n
              msg: #{error["error"]}"
      end

      case response[:status]
      when "subscribed"
        Spree.user_class.where(email: email).update_all(subscribed: true)
      when "unsubscribed"
        Spree.user_class.where(email: email).update_all(subscribed: false)
      end
    end
  end
end
