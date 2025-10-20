# template.rb


# Add gems
gem "devise"                             # Authentication
gem "pundit"                             # Authorization
gem "pg", "~> 1.6.2"                     # PostgreSQL adapter
gem "redis", "~> 5.0"                    # Redis client
gem "redis-session-store"                # Redis-backed session store
gem "rack-attack"                        # Rate limiting and throttling

###############################################################################
# SECURITY & ENCRYPTION
###############################################################################
gem "lockbox"                            # Encryption
gem "blind_index"                        # Encrypted searchable fields
gem "invisible_captcha"                  # Spam protection

###############################################################################
# AUDITING & VERSIONING
###############################################################################
gem "paper_trail"                        # Model versioning
gem "audits1984"                         # Audit logging
gem "console1984"                        # Console access auditing
gem "acts_as_paranoid"                   # Soft deletes

###############################################################################
# SEARCH & INDEXING
###############################################################################
gem "pg_search"                          # PostgreSQL full-text search
gem "hashid-rails"                       # Obfuscate IDs
gem "friendly_id"                        # Slugs and permalinks

###############################################################################
# STATE MACHINES
###############################################################################
gem "aasm"                               # State machines

###############################################################################
# ANALYTICS & MONITORING
###############################################################################
gem "okcomputer"                         # Health checks
gem "ahoy_matey"                         # Analytics
gem "ahoy_email"                         # Email analytics
gem "blazer"                             # BI dashboard
gem "statsd-instrument"                  # StatsD metrics
gem "rails_performance"                  # Performance monitoring

###############################################################################
# EMAIL
###############################################################################
gem "premailer-rails"                    # Inline CSS for emails
gem "email_reply_parser"                 # Parse email replies
gem "mailkick"                           # Email unsubscribe management

###############################################################################
# BACKGROUND JOBS
###############################################################################
gem "mission_control-jobs"               # Job dashboard

###############################################################################
# UTILITIES
###############################################################################
gem "browser"                            # Browser detection
gem "strong_migrations"                  # Safe migrations

###############################################################################
# UI & FRONTEND
###############################################################################
gem "tailwindcss-rails"                  # Tailwind CSS


###############################################################################
# FEATURE FLAGS & CONFIGURATION
###############################################################################
gem "flipper"                            # Feature flags
gem "flipper-active_record"              # ActiveRecord adapter for Flipper
gem "flipper-ui"                         # UI for Flipper
gem "flipper-active_support_cache_store"

###############################################################################
# ENVIRONMENT VARIABLES
###############################################################################
gem "dotenv-rails"                       # Environment variables

gem_group :development, :test do
  gem "rspec-rails", "~> 7.1"          # Testing framework
  gem "factory_bot_rails"              # Test data factories
  gem "faker"                          # Fake data generation
  gem "shoulda-matchers"               # RSpec matchers
  gem "rubocop-capybara", "~> 2.22", ">= 2.22.1"
  gem "rubocop-rspec", "~> 3.6"
  gem "rubocop-rspec_rails", "~> 2.31"
  gem "relaxed-rubocop"
  gem "query_count"                    # SQL query counter
  gem "bullet"                         # N+1 query detection
end

gem_group :development do
  gem "actual_db_schema"                 # Rolls back phantom migrations
  gem "annotaterb"                       # Annotate models
  gem "listen", "~> 3.9"                 # File watcher
  gem "letter_opener_web"                # Preview emails
  gem "foreman"                          # Process manager
  gem "awesome_print"                    # Pretty print objects
  gem "rack-mini-profiler", "~> 3.3", require: false # Performance profiling
  gem "stackprof" # Used by rack-mini-profiler for flamegraphs
end

# Configure database to use PostgreSQL
remove_file "config/database.yml"
create_file "config/database.yml", <<~YAML
  default: &default
    adapter: postgresql
    encoding: unicode
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

  development:
    <<: *default
    database: #{app_name}_development

  test:
    <<: *default
    database: #{app_name}_test

  production:
    <<: *default
    database: #{app_name}_production
    username: #{app_name}
    password: <%= ENV["#{app_name.upcase}_DATABASE_PASSWORD"] %>
YAML

after_bundle do
  # Generate Devise
  generate "devise:install"
  generate "devise", "User"

  # Add fields to User
  generate "migration", "AddFieldsToUsers first_name:string last_name:string access_level:integer"

  # Update the migration to add default and null constraint for access_level
  in_root do
    migration_file = Dir.glob("db/migrate/*_add_fields_to_users.rb").first
    if migration_file
      # Replace the access_level line with one that has default and null constraint
      gsub_file migration_file,
        /add_column :users, :access_level, :integer$/,
        "add_column :users, :access_level, :integer, default: 0, null: false"
    end
  end

  # Generate Lockbox master key using Lockbox.generate_key
  # This needs to run after bundle install, so Lockbox is available
  lockbox_key = `rails runner "require 'lockbox'; puts Lockbox.generate_key"`.strip

  # Add lockbox key to credentials programmatically
  # Create a Ruby script that directly writes to credentials
  create_file 'tmp/add_lockbox_to_credentials.rb', <<~RUBY, force: true
    require 'active_support/encrypted_configuration'
    require 'yaml'

    # Path to credentials files
    credentials_path = Rails.root.join('config/credentials.yml.enc')
    key_path = Rails.root.join('config/master.key')

    # Read the key
    key = File.read(key_path).strip

    # Create encrypted configuration instance
    credentials = ActiveSupport::EncryptedConfiguration.new(
      config_path: credentials_path,
      key_path: key_path,
      env_key: 'RAILS_MASTER_KEY',
      raise_if_missing_key: true
    )

    # Read existing credentials
    current_config = credentials.config

    # Parse as YAML if it's a string, and ensure we have a hash with string keys
    if current_config.is_a?(String)
      current_config = YAML.safe_load(current_config, permitted_classes: [Symbol]) || {}
    end

    # Convert all keys to strings recursively
    current_config = current_config.deep_stringify_keys if current_config.respond_to?(:deep_stringify_keys)

    # Add lockbox config if not present
    unless current_config.key?('lockbox')
      current_config['lockbox'] = { 'master_key' => '#{lockbox_key}' }

      # Write back to credentials - ensure clean YAML format
      yaml_content = current_config.to_yaml
      # Remove the YAML document separator for cleaner output
      yaml_content = yaml_content.sub(/^---\\n/, '')
      # Add blank line before lockbox section for better readability
      yaml_content = yaml_content.sub(/^lockbox:/, "\\nlockbox:")

      credentials.write(yaml_content)
      puts "✓ Added lockbox master_key to credentials"
    else
      puts "⚠ Lockbox config already exists in credentials"
    end
  RUBY

  rails_command "runner tmp/add_lockbox_to_credentials.rb"
  remove_file 'tmp/add_lockbox_to_credentials.rb'

  initializer 'lockbox.rb', <<~RUBY
    # Set Lockbox master key from credentials
    if Rails.application.credentials.lockbox&.key?(:master_key)
      Lockbox.master_key = Rails.application.credentials.lockbox[:master_key]
    else
      Rails.logger.warn "Lockbox master_key not found in credentials. Please add it by running: rails credentials:edit"
    end
  RUBY

  initializer 'okcomputer.rb', <<~RUBY
    # frozen_string_literal: true

    # https://github.com/jphenow/okcomputer#registering-additional-checks
    #
    # class MyCustomCheck < OKComputer::Check
    #   def call
    #     if rand(10).even?
    #       "Even is great!"
    #     else
    #       mark_failure
    #       "We don't like odd numbers"
    #     end
    #   end
    # end

    OkComputer::Registry.register "database", OkComputer::ActiveRecordCheck.new
    OkComputer::Registry.register "cache", OkComputer::CacheCheck.new

    OkComputer::Registry.register "app_version", OkComputer::AppVersionCheck.new
    OkComputer::Registry.register "action_mailer", OkComputer::ActionMailerCheck.new

    # Run checks in parallel
    OkComputer.check_in_parallel = true

    # Log when health checks are run
    OkComputer.logger = Rails.logger
  RUBY

  generate "rails_performance:install"

  initializer 'rails_performance.rb', <<~RUBY
    RailsPerformance.setup do |config|
      config.redis    = Redis.new(url: ENV["REDIS_URL"].presence || "redis://127.0.0.1:6379/0")
      config.duration = 4.hours

      config.enabled  = true

      # protect with authentication
      config.verify_access_proc = proc { |controller|
        controller.current_user&.admin_access?
      }

      # Ignore admin and performance paths
      config.ignored_paths = ['/admin', '/rails/performance']

      config.home_link = '/'
      config.skipable_rake_tasks = ['webpacker:compile']
    end if defined?(RailsPerformance)
  RUBY

  initializer 'session_store.rb', <<~RUBY
    # Use Redis for session storage
    Rails.application.config.session_store :redis_store,
      servers: ENV.fetch("REDIS_URL") { "redis://localhost:6379/2/session" },
      expire_after: 90.minutes,
      key: "_#{Rails.application.class.module_parent_name.underscore}_session",
      threadsafe: true,
      signed: true
  RUBY

  initializer 'rack_attack.rb', <<~RUBY
    # Configure Rack Attack for rate limiting
    class Rack::Attack
      # Use Redis for Rack Attack storage
      Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
        url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/5" }
      )

      # Throttle all requests by IP (300 req/5 minutes)
      throttle('req/ip', limit: 300, period: 5.minutes) do |req|
        req.ip unless req.path.start_with?('/assets')
      end

      # Throttle login attempts by email
      throttle('logins/email', limit: 5, period: 20.seconds) do |req|
        if req.path == '/users/sign_in' && req.post?
          req.params['user']&.dig('email')&.to_s&.downcase&.gsub(/\\s+/, "")
        end
      end

      # Throttle password reset attempts
      throttle('password_resets/email', limit: 3, period: 20.minutes) do |req|
        if req.path == '/users/password' && req.post?
          req.params['user']&.dig('email')&.to_s&.downcase&.gsub(/\\s+/, "")
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
    end
  RUBY

  # Configure cache store to use Redis in production
  inject_into_file 'config/environments/production.rb', after: "Rails.application.configure do\n" do
    <<~RUBY
  # Use Redis for caching
  config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } }

  # Enable Rack Attack middleware
  config.middleware.use Rack::Attack

    RUBY
  end

  # Configure cache store to use Redis in development
  inject_into_file 'config/environments/development.rb', after: "Rails.application.configure do\n" do
    <<~RUBY
  # Use Redis for caching (shared across processes)
  config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } }

  # Enable Rack Attack middleware (useful for testing rate limits)
  config.middleware.use Rack::Attack

    RUBY
  end

  inject_into_file 'app/models/application_record.rb',
    "  include PgSearch::Model\n",
    after: "primary_abstract_class\n"

  inject_into_file 'app/models/application_record.rb',
    "  has_paper_trail\n",
    after: "include PgSearch::Model\n"

  generate "devise:views"
  generate "pg_search:migration:multisearch"
  generate "lockbox:audits"
  generate "pundit:install"
  generate "ahoy:install"
  generate "ahoy:messages --encryption=lockbox"
  generate "ahoy:clicks"
  generate "annotate_rb:install"
  generate "blazer:install"
  generate "flipper:setup"
  generate "bullet:install"
  generate "strong_migrations:install"
  generate "solid_queue:install"
  generate "paper_trail:install"
  generate "mailkick:install"
  generate "mailkick:views"

  # Set up RSpec
  generate "rspec:install"

  # Create and run migrations
  rails_command "db:create"
  rails_command "db:migrate"

  # Create a custom controller
  # generate :controller, "pages", "home"
  # route "root to: 'pages#home'"

  # Add enum and has_subscriptions to User model
  inject_into_file 'app/models/user.rb', after: "class User < ApplicationRecord\n" do
    <<~RUBY
  enum :access_level, {
    user: 0,
    admin: 1,
    super_admin: 2,
    owner: 3
  }, default: :user, null: false

  has_subscriptions

  # Helper method to check if user has any admin access
  def admin_access?
    admin? || super_admin? || owner?
  end

  # Return full name
  def full_name
    "\#{first_name} \#{last_name}".strip
  end

    RUBY
  end

  file 'app/controllers/admin/application_controller.rb', <<~RUBY
  module Admin
   class ApplicationController < ::ApplicationController
    include Pundit
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    before_action :require_admin

     # Shared admin logic here
     def index
      @current_user = current_user
     end

     private

     def require_admin
       unless current_user&.admin? || current_user&.super_admin? || current_user&.owner?
         redirect_to root_path, alert: "You are not authorized to access this area."
       end
     end

     def user_not_authorized
       flash[:alert] = "You are not authorized to perform this action."
       redirect_to(request.referrer || root_path)
     end
   end
end
  RUBY

  # Create Admin index view
  file 'app/views/admin/application/index.html.erb', <<~HTML
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p class="mt-2 text-sm text-gray-600">
          Welcome back, <%= @current_user.full_name %>
        </p>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Blazer Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-blue-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Blazer</dt>
                  <dd class="mt-1 text-sm text-gray-900">Business Intelligence & Analytics</dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <%= link_to "Open Blazer", "/admin/blazer", class: "text-blue-600 hover:text-blue-800 text-sm font-medium" %>
            </div>
          </div>
        </div>

        <% if @current_user.super_admin? || @current_user.owner? %>
        <!-- Flipper Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-purple-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Flipper</dt>
                  <dd class="mt-1 text-sm text-gray-900">Feature Flags Management</dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <%= link_to "Manage Features", "/admin/flipper", class: "text-purple-600 hover:text-purple-800 text-sm font-medium" %>
            </div>
          </div>
        </div>
        <% end %>

        <!-- Performance Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-green-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Performance</dt>
                  <dd class="mt-1 text-sm text-gray-900">Monitor Application Performance</dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <%= link_to "View Performance", "/admin/performance", class: "text-green-600 hover:text-green-800 text-sm font-medium" %>
            </div>
          </div>
        </div>

        <!-- Users Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-yellow-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Users</dt>
                  <dd class="mt-1 text-sm text-gray-900">Manage User Accounts</dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <%= link_to "Manage Users", admin_users_path, class: "text-yellow-600 hover:text-yellow-800 text-sm font-medium" %>
            </div>
          </div>
        </div>

        <!-- Health Checks Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-red-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Health Checks</dt>
                  <dd class="mt-1 text-sm text-gray-900">System Health Monitoring</dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <%= link_to "View Health", "/healthchecks", class: "text-red-600 hover:text-red-800 text-sm font-medium" %>
            </div>
          </div>
        </div>

        <!-- Mission Control Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
          <div class="p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Background Jobs</dt>
                  <dd class="mt-1 text-sm text-gray-900">Monitor Background Jobs</dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <%= link_to "View Jobs", "/jobs", class: "text-indigo-600 hover:text-indigo-800 text-sm font-medium" %>
            </div>
          </div>
        </div>
      </div>
    </div>
  HTML

  # Create Admin Policy
  file 'app/policies/admin_policy.rb', <<~RUBY
    class AdminPolicy < ApplicationPolicy
      def blazer?
        user&.admin? || user&.super_admin? || user&.owner?
      end

      def flipper?
        user&.super_admin? || user&.owner?
      end

      def access_admin_endpoints?
        user&.admin? || user&.super_admin? || user&.owner?
      end
    end
  RUBY


  # Configure admin routes
  route <<~RUBY
    namespace :admin do
      root to: "application#index"

      mount Blazer::Engine, at: "blazer", constraints: ->(request) {
        user = User.find_by(id: request.session[:user_id])
        user && AdminPolicy.new(user, :admin).blazer?
      }

      mount Flipper::UI.app(Flipper), at: "flipper", constraints: ->(request) {
        user = User.find_by(id: request.session[:user_id])
        user && AdminPolicy.new(user, :admin).flipper?
      }

      mount RailsPerformance::Engine, at: "performance", constraints: ->(request) {
        user = User.find_by(id: request.session[:user_id])
        user && AdminPolicy.new(user, :admin).access_admin_endpoints?
      }

      resources :users, shallow: true
    end
  RUBY

  # Mount OkComputer health checks
  route <<~RUBY
    mount OkComputer::Engine, at: "/healthchecks"
  RUBY

  inject_into_file 'app/mailers/application_mailer.rb',
    "  has_history\nutm_params\n",
    after: "class ApplicationMailer < ActionMailer::Base\n"

  inject_into_file 'app/controllers/application_controller.rb',
    "  include Pundit::Authorization\n  before_action :set_paper_trail_whodunnit\n",
    after: "class ApplicationController < ActionController::Base\n"

  # Create GitHub workflows
  empty_directory '.github/workflows'

  file '.github/workflows/check-indexes.yml', <<~YAML
    name: Check Indexes
    on:
      pull_request:
        paths:
          - 'db/migrate/**.rb'

    jobs:
      check-indexes:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
            with:
              fetch-depth: 0

          - name: Check Migration Indexes
            uses: speedshop/ids_must_be_indexed@v1.2.1
  YAML

  # Run migrations one final time to catch any remaining pending migrations
  rails_command "db:migrate"

  # Git initialization
  git :init
  git add: "."
  git commit: "-m 'Initial commit (from @jaspermayone/rails-template)'"
end
