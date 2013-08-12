module Rapns
  module Daemon
    class AppRunner
      class << self
        attr_reader :runners
      end

      @runners = {}

      def self.enqueue(notification)
        if app = runners[notification.app_id]
          app.enqueue(notification)
        else
          Rapns.logger.error("No such app '#{notification.app_id}' for notification #{notification.id}.")
        end
      end

      def self.sync
        apps = Rapns::App.for_daemon_id(Rapns.config.daemon_id)

        apps.each do |app|
          if !app.job.nil? && app.job.status == Rapns::JobStatus::New
            next
          else
            sync_app(app) 
          end
        end
        
        removed = runners.keys - apps.map(&:id)
        removed.each { |app_id| runners.delete(app_id).stop }
      end

      def self.sync_app(app)
        if runners[app.id]
          runners[app.id].sync(app)
        else
          runner = new_runner(app)
          begin
            runner.start
            runners[app.id] = runner
          rescue StandardError => e
            Rapns.logger.error("[#{app.name}] Exception raised during startup. Notifications will not be delivered for this app.")
            Rapns.logger.error(e)
          end
        end
      end

      def self.new_runner(app)
        type = app.class.parent.name.demodulize
        "Rapns::Daemon::#{type}::AppRunner".constantize.new(app)
      end

      def self.stop
        runners.values.map(&:stop)
        runners.clear
      end

      def self.debug
        runners.values.map(&:debug)
      end

      def self.idle
        runners.values.select(&:idle?)
      end

      def self.wait
        sleep 0.1 while !runners.values.all?(&:idle?)
      end

      attr_reader :app

      def initialize(app)
        @app = app
      end

      def started
      end

      def stopped
      end

      def start
        app.connections.times { handlers << start_handler }
        started
        Rapns.logger.info("[#{app.name}] Started, #{handlers_str}.")
      end

      def stop
        handlers.map(&:stop)
        stopped
        handlers.clear
      end

      def enqueue(notification)
        queue.push(notification)
      end

      def sync(app)
        @app = app
        diff = handlers.size - app.connections
        return if diff == 0
        if diff > 0
          diff.times { decrement_handlers }
          Rapns.logger.info("[#{app.name}] Stopped #{handlers_str(diff)}. #{handlers_str} remaining.")
        else
          diff.abs.times { increment_handlers }
          Rapns.logger.info("[#{app.name}] Started #{handlers_str(diff)}. #{handlers_str} remaining.")
        end
      end

      def decrement_handlers
        handlers.pop.stop
      end

      def increment_handlers
        handlers << start_handler
      end

      def debug
        Rapns.logger.info <<-EOS

#{@app.name}:
  handlers: #{num_handlers}
  queued: #{queue_size}
  idle: #{idle?}
        EOS
      end

      def idle?
        queue.notifications_processed?
      end

      def queue_size
        queue.size
      end

      def num_handlers
        handlers.size
      end

      protected

      def start_handler
        handler = new_delivery_handler
        handler.queue = queue
        handler.start
        handler
      end

      def queue
        @queue ||= Rapns::Daemon::DeliveryQueue.new
      end

      def handlers
        @handler ||= []
      end

      def handlers_str(count = app.connections)
        count = count.abs
        str = count == 1 ? 'handler' : 'handlers'
        "#{count} #{str}"
      end
    end
  end
end
