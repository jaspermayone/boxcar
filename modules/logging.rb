# frozen_string_literal: true

say 'Setting up structured logging...', :green

gem 'lograge'
gem 'logstop'

say '   Creating Lograge initializer...', :cyan
initializer 'lograge.rb', <<~RUBY
  # frozen_string_literal: true

  return unless defined?(Lograge)

  Rails.application.configure do
    # Enable lograge for structured logging
    config.lograge.enabled = true

    # Use JSON format in production for log aggregation
    config.lograge.formatter = if Rails.env.production?
                                  Lograge::Formatters::Json.new
                                else
                                  Lograge::Formatters::KeyValue.new
                                end

    # Include request_id for tracing across services
    config.lograge.custom_options = lambda do |event|
      {
        request_id: event.payload[:request_id],
        user_id: event.payload[:user_id],
        ip: event.payload[:ip],
        host: event.payload[:host]
      }.compact
    end

    # Add custom data to the payload
    config.lograge.custom_payload do |controller|
      {
        request_id: controller.request.request_id,
        user_id: controller.try(:current_user)&.id,
        ip: controller.request.remote_ip,
        host: controller.request.host
      }
    end

    # Keep original Rails logs in development
    config.lograge.keep_original_rails_log = Rails.env.development?
  end
RUBY

say '   Creating Logstop initializer...', :cyan
initializer 'logstop.rb', <<~RUBY
  # frozen_string_literal: true

  # Logstop filters sensitive data from logs
  # By default it filters: email, phone, credit card, SSN, IP addresses

  if defined?(Logstop)
    Logstop.guard(Rails.logger)

    # Add custom scrubbers for application-specific sensitive data
    # Logstop.scrub(pattern, replacement)
    #
    # Example: Scrub API keys
    # Logstop.scrub(/api_key=\\w+/, 'api_key=[FILTERED]')
  end
RUBY

say 'Structured logging configured!', :green
say '   Logs include request_id for tracing', :cyan
say '   PII is automatically filtered by Logstop', :cyan
