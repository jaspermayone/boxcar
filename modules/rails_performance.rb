# frozen_string_literal: true

say 'Setting up Rails Performance monitoring...', :green

gem 'rails_performance'

# Note: rails_performance doesn't have an install generator
# We create the initializer manually below

say '   Creating Rails Performance initializer...', :cyan
file 'config/initializers/rails_performance.rb', <<~RUBY
  # frozen_string_literal: true

  RailsPerformance.setup do |config|
    # Storage backend (Redis required)
    config.redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))

    # Data retention
    config.duration = 4.hours

    # Enable/disable features
    config.enabled = true

    # Skip certain paths from tracking
    config.skipable_rake_tasks = %w[assets:precompile]

    # Ignore certain request paths
    config.ignored_paths = [
      '/health',
      '/assets'
    ]

    # Custom event tracking
    # config.custom_data_proc = proc { |env|
    #   {
    #     user_id: env['warden']&.user&.id
    #   }
    # }
  end if defined?(RailsPerformance)
RUBY

say 'Rails Performance configured!', :green
say '   Dashboard at /admin/performance (admin only)', :cyan
say '   Requires Redis for storage', :yellow
say '   Tracks requests, Sidekiq jobs, rake tasks, and custom events', :cyan
