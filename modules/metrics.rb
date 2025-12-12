# frozen_string_literal: true

say 'Setting up StatsD metrics...', :green

gem 'statsd-instrument'

say '   Creating StatsD initializer...', :cyan
file 'config/initializers/statsd.rb', <<~RUBY
  # frozen_string_literal: true

  StatsD.backend = if Rails.env.production?
    StatsD::Instrument::Backends::UDPBackend.new(
      ENV.fetch('STATSD_ADDR', 'localhost:8125'),
      :datadog
    )
  else
    StatsD::Instrument::Backends::LoggerBackend.new(Rails.logger)
  end

  StatsD.prefix = Rails.application.class.module_parent_name.underscore
  StatsD.default_tags = [
    "env:\#{Rails.env}",
    "app:\#{Rails.application.class.module_parent_name.underscore}"
  ]
RUBY

say '   Creating Metrics module...', :cyan
file 'app/services/metrics.rb', <<~RUBY
  # frozen_string_literal: true

  # Centralized metrics helper
  #
  # Usage:
  #   Metrics.increment('user.signup')
  #   Metrics.gauge('queue.size', queue.size)
  #   Metrics.measure('api.request') { api_call }
  #   Metrics.histogram('response.size', response.body.size)
  #
  module Metrics
    class << self
      # Count occurrences
      def increment(name, value = 1, tags: [])
        StatsD.increment(name, value, tags: tags)
      end

      # Track current value
      def gauge(name, value, tags: [])
        StatsD.gauge(name, value, tags: tags)
      end

      # Measure timing of a block
      def measure(name, tags: [], &block)
        StatsD.measure(name, tags: tags, &block)
      end

      # Track distribution of values
      def histogram(name, value, tags: [])
        StatsD.histogram(name, value, tags: tags)
      end

      # Track unique values
      def set(name, value, tags: [])
        StatsD.set(name, value, tags: tags)
      end

      # Time a block and record
      def time(name, tags: [])
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        histogram("\#{name}.duration", (duration * 1000).round, tags: tags)
        result
      end
    end
  end
RUBY

say '   Creating request metrics middleware...', :cyan
file 'app/middleware/request_metrics.rb', <<~RUBY
  # frozen_string_literal: true

  class RequestMetrics
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      status, headers, response = @app.call(env)

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      tags = [
        "method:\#{request.request_method}",
        "status:\#{status}",
        "controller:\#{env['action_controller.instance']&.class&.name || 'unknown'}"
      ]

      StatsD.histogram('http.request.duration', (duration * 1000).round, tags: tags)
      StatsD.increment('http.request.count', tags: tags)

      [status, headers, response]
    rescue => e
      StatsD.increment('http.request.error', tags: ["error:\#{e.class.name}"])
      raise
    end
  end
RUBY

say '   Adding middleware to application...', :cyan
inject_into_file 'config/application.rb', after: "class Application < Rails::Application\n" do
  "    config.middleware.use RequestMetrics\n"
end

say '   Adding to .env.development...', :cyan
append_to_file '.env.development', "STATSD_ADDR=localhost:8125\n"

say 'StatsD metrics configured!', :green
say '   Use Metrics.increment, .gauge, .measure, .histogram', :cyan
say '   Request metrics automatically tracked', :cyan
say '   Set STATSD_ADDR in production', :yellow
