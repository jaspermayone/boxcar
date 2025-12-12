# frozen_string_literal: true

say 'Setting up caching strategies...', :green

gem 'identity_cache'
gem 'cityhash' # Required for identity_cache

say '   Configuring IdentityCache...', :cyan
initializer 'identity_cache.rb', <<~RUBY
  # frozen_string_literal: true

  # IdentityCache - Blob level caching for Active Record
  # See: https://github.com/Shopify/identity_cache

  IdentityCache.logger = Rails.logger
  IdentityCache.cache_backend = Rails.cache
RUBY

say '   Creating Cacheable concern...', :cyan
file 'app/models/concerns/cacheable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include in models for identity caching
  #
  # Usage:
  #   class User < ApplicationRecord
  #     include Cacheable
  #
  #     cache_index :email
  #     cache_has_many :posts
  #   end
  #
  #   User.fetch(1)              # Cached fetch by id
  #   User.fetch_by_email(email) # Cached fetch by index
  #
  module Cacheable
    extend ActiveSupport::Concern

    included do
      include IdentityCache
    end

    class_methods do
      # Expire cache when record is updated
      def expire_cache_for(record)
        record.expire_cache if record.respond_to?(:expire_cache)
      end
    end
  end
RUBY

say '   Creating CacheHelper...', :cyan
file 'app/helpers/cache_helper.rb', <<~RUBY
  # frozen_string_literal: true

  # Helper methods for view caching
  #
  # Russian Doll Caching:
  #   The key insight is that when a nested object changes,
  #   only its cache (and parent caches) are invalidated.
  #
  # Example view structure:
  #   <% cache @project do %>
  #     <%= render @project.tasks %>
  #   <% end %>
  #
  #   # _task.html.erb
  #   <% cache task do %>
  #     <%= task.name %>
  #     <%= render task.comments %>
  #   <% end %>
  #
  module CacheHelper
    # Cache with automatic expiry based on record updated_at
    # Also includes a version number for manual cache busting
    #
    # Usage:
    #   <% cache_with_version @user, 'v2' do %>
    #     ...
    #   <% end %>
    #
    def cache_with_version(record, version = 'v1', options = {}, &block)
      cache([version, record], options, &block)
    end

    # Cache a collection with automatic key generation
    # Useful for lists that change frequently
    #
    # Usage:
    #   <% cache_collection @users do |user| %>
    #     <%= render user %>
    #   <% end %>
    #
    def cache_collection(collection, options = {}, &block)
      cache([collection.cache_key_with_version, collection.size], options, &block)
    end

    # Time-based cache for content that should refresh periodically
    #
    # Usage:
    #   <% cache_for 5.minutes, 'dashboard_stats' do %>
    #     ...
    #   <% end %>
    #
    def cache_for(duration, key, options = {}, &block)
      expires_key = (Time.current.to_i / duration.to_i)
      cache([key, expires_key], options, &block)
    end
  end
RUBY

say '   Creating CacheWarmer job...', :cyan
file 'app/jobs/cache_warmer_job.rb', <<~RUBY
  # frozen_string_literal: true

  # Warm caches for frequently accessed data
  #
  # Schedule this job to run periodically:
  #   CacheWarmerJob.perform_later
  #
  # Or warm specific caches:
  #   CacheWarmerJob.perform_later(caches: ['users', 'settings'])
  #
  class CacheWarmerJob < ApplicationJob
    queue_as :low

    def perform(caches: nil)
      warmers = caches || default_warmers
      warmers.each { |warmer| send("warm_\#{warmer}") }
    end

    private

    def default_warmers
      %w[settings]
    end

    # Add your cache warming methods here
    #
    # def warm_users
    #   User.active.find_each do |user|
    #     Rails.cache.fetch(user.cache_key_with_version) { user }
    #   end
    # end

    def warm_settings
      # Example: warm application settings
      # AppConfig.all.each do |config|
      #   Rails.cache.fetch(['app_config', config.key]) { config.value }
      # end
    end
  end
RUBY

say '   Documenting caching patterns...', :cyan
file 'docs/caching.md', <<~MARKDOWN
  # Caching Strategies

  ## Fragment Caching (Views)

  Basic fragment cache:
  ```erb
  <% cache @user do %>
    <%= @user.name %>
  <% end %>
  ```

  ## Russian Doll Caching

  Nested caches that auto-expire:
  ```erb
  <% cache @project do %>
    <h1><%= @project.name %></h1>
    <%= render @project.tasks %>
  <% end %>

  <!-- _task.html.erb -->
  <% cache task do %>
    <%= task.name %>
  <% end %>
  ```

  **Important:** Use `touch: true` on associations:
  ```ruby
  class Task < ApplicationRecord
    belongs_to :project, touch: true
  end
  ```

  ## Model Caching (IdentityCache)

  ```ruby
  class User < ApplicationRecord
    include Cacheable

    cache_index :email
    cache_has_many :posts, embed: true
  end

  # Usage
  User.fetch(1)                    # Cached
  User.fetch_by_email('a@b.com')   # Cached
  user.fetch_posts                 # Cached with user
  ```

  ## Low-Level Caching

  ```ruby
  Rails.cache.fetch('expensive_operation', expires_in: 1.hour) do
    ExpensiveService.call
  end
  ```

  ## Cache Warming

  ```ruby
  # Run periodically
  CacheWarmerJob.perform_later

  # Or specific caches
  CacheWarmerJob.perform_later(caches: ['users'])
  ```
MARKDOWN

say 'Caching strategies configured!', :green
say '   Use `include Cacheable` in models for identity caching', :cyan
say '   See docs/caching.md for patterns', :cyan
