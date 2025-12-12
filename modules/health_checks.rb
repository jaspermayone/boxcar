# frozen_string_literal: true

say 'Setting up OkComputer for health checks...', :green

gem 'okcomputer'

say '   Creating OkComputer initializer...', :cyan
initializer 'okcomputer.rb', <<~RUBY
  # frozen_string_literal: true

  # OkComputer Health Checks
  # https://github.com/jphenow/okcomputer
  #
  # Custom check example:
  # class MyCustomCheck < OkComputer::Check
  #   def check
  #     if some_condition
  #       mark_message "All good!"
  #     else
  #       mark_failure
  #       mark_message "Something went wrong"
  #     end
  #   end
  # end

  OkComputer.mount_at = 'health'

  # Core checks
  OkComputer::Registry.register 'database', OkComputer::ActiveRecordCheck.new
  OkComputer::Registry.register 'cache', OkComputer::CacheCheck.new
  OkComputer::Registry.register 'app_version', OkComputer::AppVersionCheck.new
  OkComputer::Registry.register 'action_mailer', OkComputer::ActionMailerCheck.new

  # Redis check (if using Redis)
  if ENV['REDIS_URL'].present?
    OkComputer::Registry.register 'redis', OkComputer::RedisCheck.new(url: ENV['REDIS_URL'])
  end

  # Run checks in parallel
  OkComputer.check_in_parallel = true

  # Log when health checks are run
  OkComputer.logger = Rails.logger

  # Require authentication for detailed health info in production
  if Rails.env.production?
    OkComputer.require_authentication(
      ENV.fetch('HEALTH_CHECK_USER', 'health'),
      ENV.fetch('HEALTH_CHECK_PASSWORD', 'check'),
      except: %w[default]
    )
  end
RUBY

say 'OkComputer health checks configured!', :green
say '   Endpoints:', :cyan
say '     GET /health - all checks', :cyan
say '     GET /health/database - database check', :cyan
say '     GET /health/cache - cache check', :cyan
say '     GET /health/all - all checks as JSON', :cyan
