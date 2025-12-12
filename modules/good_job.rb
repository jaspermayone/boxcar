# frozen_string_literal: true

say 'Setting up GoodJob for background processing...', :green

gem 'good_job'

say '   Configuring GoodJob...', :cyan
initializer 'good_job.rb', <<~RUBY
  # frozen_string_literal: true

  Rails.application.configure do
    # Use GoodJob as the Active Job adapter
    config.active_job.queue_adapter = :good_job

    config.good_job = {
      # Execution mode (:async, :external, :inline)
      # :async - runs jobs in the web process (good for low-volume)
      # :external - runs jobs in a separate process (recommended for production)
      # :inline - runs jobs immediately (good for testing)
      execution_mode: Rails.env.production? ? :external : :async,

      # Maximum threads per process
      max_threads: ENV.fetch('GOOD_JOB_MAX_THREADS', 5).to_i,

      # Poll interval for checking new jobs (in seconds)
      poll_interval: ENV.fetch('GOOD_JOB_POLL_INTERVAL', 5).to_i,

      # Queues to process (priority order)
      queues: ENV.fetch('GOOD_JOB_QUEUES', '*'),

      # Cron-like recurring jobs
      enable_cron: true,
      cron: {
        # Example: cleanup old sessions daily at 3am
        # cleanup_sessions: {
        #   cron: '0 3 * * *',
        #   class: 'CleanupSessionsJob',
        #   description: 'Remove expired sessions'
        # },

        # Example: send weekly digest every Monday at 9am
        # weekly_digest: {
        #   cron: '0 9 * * 1',
        #   class: 'WeeklyDigestJob',
        #   description: 'Send weekly email digest'
        # }
      },

      # Preserve job records for debugging (default: 14 days)
      preserve_job_records: true,
      cleanup_preserved_jobs_before_seconds_ago: 14.days.to_i,

      # Dashboard configuration
      smaller_number_is_higher_priority: true
    }
  end
RUBY

after_bundle do
  say '   Installing GoodJob...', :cyan
  rails_command 'good_job:install'

  say '   Adding GoodJob to Procfile.dev...', :cyan
  append_to_file 'Procfile.dev', "jobs: bundle exec good_job start\n"
end

say '   Creating example recurring job...', :cyan
file 'app/jobs/cleanup_job.rb', <<~RUBY
  # frozen_string_literal: true

  # Example recurring job for cleanup tasks
  # Configure schedule in config/initializers/good_job.rb
  #
  # cron: {
  #   cleanup: {
  #     cron: '0 4 * * *',  # 4am daily
  #     class: 'CleanupJob'
  #   }
  # }
  #
  class CleanupJob < ApplicationJob
    queue_as :low

    def perform
      cleanup_expired_sessions
      cleanup_old_versions
      cleanup_orphaned_records
    end

    private

    def cleanup_expired_sessions
      # Remove sessions older than 30 days
      Session.where('created_at < ?', 30.days.ago).delete_all
    end

    def cleanup_old_versions
      # Remove PaperTrail versions older than 90 days (if using paper_trail)
      return unless defined?(PaperTrail)

      PaperTrail::Version.where('created_at < ?', 90.days.ago).delete_all
    end

    def cleanup_orphaned_records
      # Add your cleanup logic here
    end
  end
RUBY

say 'GoodJob configured!', :green
say '   Dashboard at /admin/jobs', :cyan
say '   Run jobs: bundle exec good_job start', :cyan
say '   Add cron jobs in config/initializers/good_job.rb', :cyan
