# frozen_string_literal: true

say '🚞 boxcar - Rails starter kit', :cyan

TEMPLATE_ROOT = if __FILE__.start_with?("http")
                  File.dirname(__FILE__)
                else
                  __dir__
                end

@post_install_tasks = []

def apply_template(template_name, tasks = [])
  apply File.join(TEMPLATE_ROOT, "#{template_name}.rb")
  @post_install_tasks.concat(tasks)
end

gem 'jb'
gem 'awesome_print'
gem 'faraday'
gem 'dotenv-rails', groups: %i[development test]

gem_group :development do
  gem 'pry-rails'
  gem 'bullet'
  gem 'query_count'
  gem 'actual_db_schema'
  gem 'annotaterb'
  gem 'letter_opener_web'
end

file '.env.development', ""

# Bullet configuration for N+1 query detection
file 'config/initializers/bullet.rb', <<~RUBY
  # frozen_string_literal: true

  if defined?(Bullet) && Rails.env.development?
    Rails.application.configure do
      config.after_initialize do
        Bullet.enable = true
        Bullet.alert = false
        Bullet.bullet_logger = true
        Bullet.console = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
      end
    end
  end
RUBY

# Letter Opener Web for email preview in development
route <<~RUBY
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/letter_opener'
  end
RUBY

inject_into_file 'config/environments/development.rb', before: /^end$/ do
  <<~RUBY

  # Use letter_opener for email delivery
  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  RUBY
end

gsub_file 'app/controllers/application_controller.rb',
          /^\s*# Only allow modern browsers.*\n\s*allow_browser versions: :modern\n?/m,
          ''

# Initialize credentials for each environment
say 'Setting up credentials for all environments...', :green
%w[development staging production].each do |env|
  say "   Creating #{env} credentials...", :cyan
  run "EDITOR='echo' bin/rails credentials:edit --environment #{env}", abort_on_failure: false
end

# Create credentials example file
file 'config/credentials.yml.example', <<~YAML
  # Credentials structure for all environments
  # Edit with: EDITOR=nano rails credentials:edit --environment <env>
  #
  # Generate keys in rails console:
  #   Lockbox.generate_key
  #   BlindIndex.generate_key
  #   SecureRandom.hex(32)

  secret_key_base: # auto-generated

  lockbox:
    master_key: # Lockbox.generate_key

  blind_index:
    master_key: # BlindIndex.generate_key

  hashid:
    salt: # SecureRandom.hex(32)
YAML

# Database configuration (must run early)
apply_template('database')

# Core modules (always installed)
apply_template('public_identifiable')
apply_template('auth', ['run `rails db:migrate`'])
gem 'tailwindcss-rails'
apply_template('tailwind')
apply_template('pundit')
apply_template('redis')
apply_template('security')
apply_template('flipper')
apply_template('solid_queue')

# Admin dashboards
apply_template('blazer')
apply_template('rails_performance')

# Infrastructure
apply_template('health_checks')
apply_template('analytics')
apply_template('console1984')

# Common utilities
apply_template('kaminari')
apply_template('paper_trail')
apply_template('soft_delete')
apply_template('friendly_id')
apply_template('pg_search')
apply_template('aasm')
apply_template('mailkick')
apply_template('metrics')

# Apply admin routes after all admin-related modules are loaded
apply_template('admin_routes')

# Create GitHub workflows
say 'Creating GitHub workflows...', :green
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

# Configure ApplicationMailer for tracking
inject_into_file 'app/mailers/application_mailer.rb', after: "class ApplicationMailer < ActionMailer::Base\n" do
  "  has_history\n  utm_params\n"
end

# Run generators after bundle
after_bundle do
  say 'Running development tool generators...', :green

  say '   Running AnnotateRb installer...', :cyan
  rails_command 'generate annotate_rb:install'

  say '   Running Bullet installer...', :cyan
  rails_command 'generate bullet:install'
end

say ''
say ''
say '✅ boxcar setup complete!', :green
say ''

if @post_install_tasks.any?
  say 'Next steps:', :yellow
  @post_install_tasks.uniq.each { |task| say "  - #{task}", :yellow }
  say ''
end

say 'Run `cd testapp && bin/dev` to start your app', :cyan
say ''
