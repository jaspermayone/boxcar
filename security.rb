# frozen_string_literal: true

say 'Setting up security gems...', :green

gem 'lockbox'
gem 'blind_index'
gem 'invisible_captcha'
gem 'strong_migrations'

after_bundle do
  say '   Running Lockbox audits generator...', :cyan
  rails_command 'generate lockbox:audits'

  say '   Running Strong Migrations installer...', :cyan
  rails_command 'generate strong_migrations:install'
end

say '   Creating Lockbox initializer...', :cyan
initializer 'lockbox.rb', <<~RUBY
  # frozen_string_literal: true

  # Lockbox - Field-level encryption
  # https://github.com/ankane/lockbox
  #
  # Generate key with: Lockbox.generate_key

  if Rails.application.credentials.lockbox&.key?(:master_key)
    Lockbox.master_key = Rails.application.credentials.lockbox[:master_key]
  elsif ENV['LOCKBOX_MASTER_KEY'].present?
    Lockbox.master_key = ENV['LOCKBOX_MASTER_KEY']
  elsif Rails.env.production?
    raise 'Lockbox master_key not configured! Run: rails credentials:edit'
  else
    Rails.logger.warn 'Lockbox master_key not found in credentials. Add it with: rails credentials:edit'
  end
RUBY

say '   Creating BlindIndex initializer...', :cyan
initializer 'blind_index.rb', <<~RUBY
  # frozen_string_literal: true

  # Blind Index - Searchable Encryption
  # https://github.com/ankane/blind_index
  #
  # Allows searching encrypted columns without decrypting them
  # Generate key with: BlindIndex.generate_key

  if Rails.application.credentials.blind_index&.key?(:master_key)
    BlindIndex.master_key = Rails.application.credentials.blind_index[:master_key]
  elsif ENV['BLIND_INDEX_MASTER_KEY'].present?
    BlindIndex.master_key = ENV['BLIND_INDEX_MASTER_KEY']
  elsif Rails.env.production?
    raise 'BlindIndex master_key not configured! Run: rails credentials:edit'
  else
    Rails.logger.warn 'BlindIndex master_key not found in credentials. Add it with: rails credentials:edit'
  end

  # Default options
  BlindIndex.default_options[:algorithm] = :argon2id  # Most secure, recommended
  BlindIndex.default_options[:insecure_key] = false   # Require secure keys
RUBY

say '   Creating InvisibleCaptcha initializer...', :cyan
file 'config/initializers/invisible_captcha.rb', <<~RUBY
  # frozen_string_literal: true

  InvisibleCaptcha.setup do |config|
    # Minimum time (in seconds) for a human to fill out a form
    config.timestamp_threshold = 2

    # Custom honeypot field name (randomized per form by default)
    # config.honeypots = ['foo', 'bar']

    # Flash message when spam is detected
    config.timestamp_error_message = 'Something went wrong. Please try again.'

    # Enable visual mode for debugging in development
    config.visual_honeypots = Rails.env.development?
  end
RUBY

say '   Creating Encryptable concern...', :cyan
file 'app/models/concerns/encryptable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include this concern and use the DSL to encrypt sensitive fields
  #
  # Example:
  #   class User < ApplicationRecord
  #     include Encryptable
  #
  #     encrypts_field :ssn
  #     encrypts_field :phone, searchable: true
  #   end
  #
  # Migration for encrypted fields:
  #   add_column :users, :ssn_ciphertext, :text
  #   add_column :users, :phone_ciphertext, :text
  #   add_column :users, :phone_bidx, :string  # for searchable fields
  #   add_index :users, :phone_bidx
  #
  module Encryptable
    extend ActiveSupport::Concern

    class_methods do
      def encrypts_field(field_name, searchable: false)
        encrypts field_name

        if searchable
          blind_index field_name
        end
      end
    end
  end
RUBY

say '   Adding invisible_captcha to ApplicationController...', :cyan
inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', <<~RUBY
  # Invisible captcha is available in forms via: invisible_captcha
  # Add to specific controllers with: invisible_captcha only: [:create], on_spam: :spam_detected
  #
  # private
  # def spam_detected
  #   redirect_to root_path, alert: 'Spam detected.'
  # end
RUBY

say 'Security gems configured!', :green
say '   - Lockbox: Use `encrypts :field_name` in models', :cyan
say '   - BlindIndex: Use `blind_index :field_name` for searchable encrypted fields', :cyan
say '   - InvisibleCaptcha: Use `invisible_captcha` helper in forms', :cyan
say '   Generate production keys with: Lockbox.generate_key / BlindIndex.generate_key', :yellow
