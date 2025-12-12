# frozen_string_literal: true

say 'Setting up Flipper for feature flags...', :green

gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-ui'
gem 'flipper-active_support_cache_store'

after_bundle do
  say '   Running Flipper setup...', :cyan
  rails_command 'generate flipper:setup'
end

say '   Creating Flipper initializer...', :cyan
file 'config/initializers/flipper.rb', <<~RUBY
  # frozen_string_literal: true

  require 'flipper'
  require 'flipper/adapters/active_record'
  require 'flipper/adapters/active_support_cache_store'

  Flipper.configure do |config|
    config.default do
      adapter = Flipper::Adapters::ActiveRecord.new
      cached_adapter = Flipper::Adapters::ActiveSupportCacheStore.new(
        adapter,
        Rails.cache,
        expires_in: 5.minutes
      )
      Flipper.new(cached_adapter)
    end
  end

  # Register groups
  Flipper.register(:staff) do |actor, _context|
    actor.respond_to?(:admin_or_above?) && actor.admin_or_above?
  end

  Flipper.register(:admins) do |actor, _context|
    actor.respond_to?(:admin?) && actor.admin?
  end

  Flipper.register(:super_admins) do |actor, _context|
    actor.respond_to?(:super_admin?) && actor.super_admin?
  end

  # Configure Flipper UI
  Flipper::UI.configure do |config|
    config.application_breadcrumb_href = '/'
    config.feature_creation_enabled = true
    config.feature_removal_enabled = true

    if Rails.env.production?
      config.banner_text = 'Production Environment'
      config.banner_class = 'danger'
    elsif Rails.env.staging?
      config.banner_text = 'Staging Environment'
      config.banner_class = 'warning'
    end
  end
RUBY

say '   Creating Featureable concern...', :cyan
file 'app/models/concerns/featureable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include in models that can be used as Flipper actors
  #
  # Usage:
  #   class User < ApplicationRecord
  #     include Featureable
  #   end
  #
  #   Flipper.enable(:new_dashboard, user)
  #   Flipper.enabled?(:new_dashboard, user)
  #
  module Featureable
    extend ActiveSupport::Concern

    # Uses public_id if available (e.g., "user_abc123"), otherwise falls back to "ClassName;id"
    def flipper_id
      respond_to?(:public_id) ? public_id : "\#{self.class.name};\#{id}"
    end
  end
RUBY

say '   Adding Featureable to User model...', :cyan
inject_into_file 'app/models/user.rb', after: "class User < ApplicationRecord\n" do
  "  include Featureable\n"
end

say '   Creating Feature helper...', :cyan
file 'app/helpers/feature_helper.rb', <<~RUBY
  # frozen_string_literal: true

  module FeatureHelper
    # Check if a feature is enabled for the current user
    #
    # Usage in views:
    #   <% if feature_enabled?(:new_dashboard) %>
    #     <%= render 'new_dashboard' %>
    #   <% end %>
    #
    def feature_enabled?(feature, actor = current_user)
      Flipper.enabled?(feature, actor)
    end
  end
RUBY

say '   Adding Feature helper to ApplicationController...', :cyan
inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', <<~RUBY
  helper FeatureHelper
RUBY

say 'Flipper feature flags configured!', :green
say '   Dashboard at /admin/flipper (super_admin only)', :cyan
say '   Run migrations: rails db:migrate', :yellow
say '   Usage: Flipper.enable(:feature), Flipper.enabled?(:feature, user)', :cyan
