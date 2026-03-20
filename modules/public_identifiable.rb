# frozen_string_literal: true

say '🔑 Setting up public IDs (encoded_ids)...', :green

gem 'encoded_ids'

file 'config/initializers/encoded_ids.rb', <<~RUBY
  # frozen_string_literal: true

  EncodedIds.configure do |config|
    # Salt from credentials (generate with: SecureRandom.hex(32))
    config.salt = Rails.application.credentials.dig(:encoded_ids, :salt) || Rails.application.secret_key_base

    # Minimum length of the encoded ID (default: 6)
    config.min_length = 6

    # Custom alphabet (URL-safe, lowercase for consistency)
    config.alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
  end
RUBY

append_to_file '.env.development', "ENCODED_IDS_SALT=development_salt_change_in_production\n"

say '✅ Public IDs configured!', :green
say '   Include EncodedIds::HashidIdentifiable in models', :cyan
say '   Example: include EncodedIds::HashidIdentifiable', :cyan
say '   Then call: set_encoded_id_prefix :usr', :cyan
