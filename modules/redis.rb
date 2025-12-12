# frozen_string_literal: true

say 'Setting up Redis...', :green

gem 'redis'
gem 'redis-session-store'
gem 'rack-attack'

say '   Creating Redis initializer...', :cyan
initializer 'redis.rb', <<~RUBY
  # frozen_string_literal: true

  REDIS = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
RUBY

say '   Configuring Redis session store...', :cyan
initializer 'session_store.rb', <<~RUBY
  # frozen_string_literal: true

  # Use Redis for session storage
  Rails.application.config.session_store :redis_store,
    servers: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/2/session' },
    expire_after: 90.minutes,
    key: "_\#{Rails.application.class.module_parent_name.underscore}_session",
    threadsafe: true,
    signed: true
RUBY

say '   Configuring Rack::Attack...', :cyan
initializer 'rack_attack.rb', <<~RUBY
  # frozen_string_literal: true

  # Configure Rack Attack for rate limiting
  class Rack::Attack
    # Use Redis for Rack Attack storage
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/5' }
    )

    # Throttle all requests by IP (300 req/5 minutes)
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets')
    end

    # Throttle login attempts by email
    throttle('logins/email', limit: 5, period: 20.seconds) do |req|
      if req.path == '/sign_in' && req.post?
        req.params['email']&.to_s&.downcase&.gsub(/\\s+/, '')
      end
    end

    # Throttle password reset attempts
    throttle('password_resets/email', limit: 3, period: 20.minutes) do |req|
      if req.path == '/password/reset' && req.post?
        req.params['email']&.to_s&.downcase&.gsub(/\\s+/, '')
      end
    end

    # Block suspicious requests
    blocklist('block suspicious requests') do |req|
      # Block requests with suspicious patterns
      Rack::Attack::Fail2Ban.filter("pentesters-\#{req.ip}", maxretry: 5, findtime: 10.minutes, bantime: 1.hour) do
        # Return true if this is a suspicious request
        CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
        req.path.include?('/etc/passwd') ||
        req.path.include?('wp-admin') ||
        req.path.include?('wp-login')
      end
    end

    # Always allow requests from localhost in development
    safelist('allow from localhost') do |req|
      req.ip == '127.0.0.1' || req.ip == '::1' if Rails.env.development?
    end

    # Custom response for throttled requests
    self.throttled_responder = lambda do |request|
      match_data = request.env['rack.attack.match_data']
      now = Time.now.utc

      headers = {
        'Content-Type' => 'application/json',
        'Retry-After' => (match_data[:period] - (now.to_i % match_data[:period])).to_s
      }

      [429, headers, [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]]
    end
  end
RUBY

say '   Configuring cache store...', :cyan
inject_into_file 'config/environments/production.rb', after: "Rails.application.configure do\n" do
  <<~RUBY
  # Use Redis for caching
  config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' } }

  # Enable Rack Attack middleware
  config.middleware.use Rack::Attack

  RUBY
end

inject_into_file 'config/environments/development.rb', after: "Rails.application.configure do\n" do
  <<~RUBY
  # Use Redis for caching (shared across processes)
  config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' } }

  # Enable Rack Attack middleware (useful for testing rate limits)
  config.middleware.use Rack::Attack

  RUBY
end

say '   Adding Redis URL to .env.development...', :cyan
append_to_file '.env.development', "REDIS_URL=redis://localhost:6379/0\n"

say 'Redis configured!', :green
say '   - Redis connection available via REDIS constant', :cyan
say '   - Sessions stored in Redis (db 2)', :cyan
say '   - Cache stored in Redis (db 1)', :cyan
say '   - Rate limiting enabled via Rack::Attack (db 5)', :cyan
say '   Make sure Redis is running locally or set REDIS_URL', :yellow
