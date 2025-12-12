# frozen_string_literal: true

say 'Setting up Ahoy for analytics...', :green

gem 'ahoy_matey'
gem 'ahoy_email'

after_bundle do
  say '   Running Ahoy generators...', :cyan
  rails_command 'generate ahoy:install'
  rails_command 'generate ahoy:messages --encryption=lockbox'
  rails_command 'generate ahoy:clicks'
end

say '   Creating Ahoy initializer...', :cyan
file 'config/initializers/ahoy.rb', <<~RUBY, force: true
  # frozen_string_literal: true

  class Ahoy::Store < Ahoy::DatabaseStore
  end

  Ahoy.api = true
  Ahoy.server_side_visits = :when_needed

  # Mask IPs for privacy (GDPR compliance)
  Ahoy.mask_ips = true

  # Cookie settings
  Ahoy.cookies = :none  # or :all for full tracking

  # Visit duration
  Ahoy.visit_duration = 30.minutes

  # Geocoding (requires geocoder gem)
  # Ahoy.geocode = true
RUBY

say '   Creating Ahoy Email initializer...', :cyan
file 'config/initializers/ahoy_email.rb', <<~RUBY
  # frozen_string_literal: true

  # Configure ahoy_email for email tracking
  AhoyEmail.api = true

  # Default tracking options
  AhoyEmail.default_options[:message] = true      # Store message metadata
  AhoyEmail.default_options[:open] = true         # Track email opens (via tracking pixel)
  AhoyEmail.default_options[:click] = true        # Track link clicks
  AhoyEmail.default_options[:utm_params] = false  # Don't add UTM parameters

  # Register the message subscriber to store messages
  AhoyEmail.subscribers << AhoyEmail::MessageSubscriber

  # Configure message model
  AhoyEmail.message_model = -> { Ahoy::Message }

  # Track email opens and clicks
  # Note: Opens require an image to be loaded, which may be blocked by email clients
  # Clicks work by redirecting through the application before going to the final URL
RUBY

say '   Creating Trackable concern...', :cyan
file 'app/models/concerns/trackable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include in ApplicationController for visit/event tracking
  #
  # Usage in controllers:
  #   ahoy.track "Viewed Product", product_id: product.id
  #
  # Usage in views:
  #   <% ahoy.track "Viewed Page", page: request.path %>
  #
  module Trackable
    extend ActiveSupport::Concern

    included do
      # Track visits automatically
      # before_action :track_ahoy_visit
    end

    def track_event(name, properties = {})
      ahoy.track(name, properties)
    end
  end
RUBY

say '   Adding Ahoy to ApplicationController...', :cyan
inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', <<~RUBY
  include Trackable
RUBY

say '   Configuring ApplicationMailer for tracking...', :cyan
inject_into_file 'app/mailers/application_mailer.rb', after: "class ApplicationMailer < ActionMailer::Base\n" do
  "  has_history\n  utm_params\n"
end

say 'Ahoy analytics configured!', :green
say '   Track events: ahoy.track "Event Name", key: value', :cyan
say '   Email tracking enabled for opens and clicks', :cyan
say '   Run migrations: rails db:migrate', :yellow
