# frozen_string_literal: true

say '🔑 Setting up public IDs (encoded_ids)...', :green

gem 'encoded_ids'

file 'config/initializers/encoded_ids.rb', <<~RUBY
  # frozen_string_literal: true

  EncodedIds.configure do |config|
    # Salt from credentials (generate with: SecureRandom.hex(32))
    # rails credentials:edit → add: hashid: { salt: "..." }
    config.hashid_salt = Rails.application.credentials.dig(:hashid, :salt) || ENV["HASHID_SALT"]

    # Minimum length of the hash portion (before prefix)
    config.hashid_min_length = 8

    # Character set for hash generation (lowercase + numbers)
    config.hashid_alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"

    # Separator between prefix and hash (e.g. usr_abc123)
    config.separator = "_"

    # false = /users/abc123 (cleaner), true = /users/usr_abc123 (Stripe style)
    config.use_prefix_in_routes = false
  end
RUBY

append_to_file '.env.development', "ENCODED_IDS_SALT=development_salt_change_in_production\n"

say '✅ Public IDs configured!', :green
say '   Include EncodedIds::HashidIdentifiable in models', :cyan
say '   Example: include EncodedIds::HashidIdentifiable', :cyan
say '   Then call: set_encoded_id_prefix :usr', :cyan
