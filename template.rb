# template.rb


# Add gems
gem "devise"                             # Authentication
gem "okcomputer"
gem "lockbox"
gem "blind_index"
gem "mission_control-jobs"
gem "pg_search"
gem "paper_trail"
gem "strong_migrations"
gem "hashid-rails"
gem "friendly_id"
gem "aasm"
gem "premailer-rails"
gem "email_reply_parser"
gem "invisible_captcha"
gem "browser"
gem "ahoy_matey"                         # Analytics
gem "ahoy_email"                         # Email analytics
gem "mailkick"
gem "blazer"                             # BI dashboard
gem "statsd-instrument"                  # StatsD metrics
gem "audits1984"                         # Audit logging
gem "console1984"                        # Console access auditing
gem "tailwindcss-rails"                  # Tailwind CSS
gem "pundit"                             # Authorization
gem "acts_as_paranoid"
gem "pg", "~> 1.6.2"
gem 'rails_performance'


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

  inject_into_file 'app/models/application_record.rb',
    "  include PgSearch::Model\n",
    after: "primary_abstract_class\n"

  inject_into_file 'app/models/application_record.rb',
    "  has_paper_trail\n",
    after: "include PgSearch::Model\n"

  inject_into_file 'app/models/application_record.rb',
    "  has_paper_trail\n",
    after: "# include Hashid::Rails\n"


  generare "rails_performance:install"
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
