module Rapns
	class Job < ActiveRecord::Base
		self.table_name = 'rapns_jobs'

    if Rapns.attr_accessible_available?
      attr_accessible :job_id, :daemon_id, :status, :status_changed_at, :feedback_checked_at
    end

		has_one :app, :class_name => 'Rapns::App'
    has_many :notifications, :class_name => 'Rapns::Notification'

		before_create :set_status_changed_at_to_now

    scope :for_daemon_id, lambda { |daemon_id|
      where(daemon_id: daemon_id) 
    }

    scope :for_new, lambda {
      where(status: Rapns::JobStatus::New) 
    }

    scope :for_ready, lambda {
      where(status: Rapns::JobStatus::Ready) 
    }

    scope :for_sent, lambda {
      where(status: Rapns::JobStatus::Sent) 
    }

    scope :for_completed, lambda {
      where(status: Rapns::JobStatus::Completed) 
    }

		def set_status_changed_at_to_now
	    self.status_changed_at = Time.now.utc
	  end

	  def status=(value)
	    set_status_changed_at_to_now
	    write_attribute(:status, value)
	  end

		def notifications_total
	  	Rapns::Notification.count(:all, :conditions=>['job_id = ?', self.id])
	  end

	  def notifications_remaining
	  	Rapns::Notification.count(:all, :conditions=>['job_id = ? AND delivered = ? AND failed = ?', self.id, false, false])
	  end

		def notifications_delivered
	  	Rapns::Notification.count(:all, :conditions=>['job_id = ? AND delivered = ?', self.id, true])
	  end

		def notifications_failed
			Rapns::Notification.count(:all, :conditions=>['job_id = ? AND failed = ?', self.id, true])
	  end
	end

	module JobStatus
  	New = 0
  	Ready = 1
  	Sent = 2
  	Completed = 3
	end
end
