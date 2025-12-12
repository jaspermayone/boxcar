# frozen_string_literal: true

say '🔑 Setting up public IDs (hashid-rails)...', :green

gem 'hashid-rails'

file 'app/models/concerns/public_identifiable.rb', <<~RUBY
  # frozen_string_literal: true

  module PublicIdentifiable
    SEPARATOR = '_'

    extend ActiveSupport::Concern

    included do
      include Hashid::Rails
      class_attribute :public_id_prefix
    end

    def public_id
      "\#{self.class.get_public_id_prefix}\#{SEPARATOR}\#{hashid}"
    end

    module ClassMethods
      def set_public_id_prefix(prefix)
        self.public_id_prefix = prefix.to_s.downcase
      end

      def find_by_public_id(id)
        return nil unless id.is_a?(String) && id.include?(SEPARATOR)

        prefix, hash = id.split(SEPARATOR, 2)
        return nil unless prefix.downcase == get_public_id_prefix

        find_by_hashid(hash)
      end

      def find_by_public_id!(id)
        obj = find_by_public_id(id)
        raise ActiveRecord::RecordNotFound.new(nil, name) if obj.nil?

        obj
      end

      def get_public_id_prefix
        return @_public_id_prefix if defined?(@_public_id_prefix)

        if public_id_prefix.present?
          @_public_id_prefix = public_id_prefix.downcase
        else
          raise NotImplementedError, "The \#{name} model includes PublicIdentifiable but set_public_id_prefix hasn't been called."
        end
      end
    end
  end
RUBY

file 'config/initializers/hashid.rb', <<~RUBY
  Hashid::Rails.configure do |config|
    # Salt from credentials (generate with: SecureRandom.hex(32))
    config.salt = Rails.application.credentials.dig(:hashid, :salt) || Rails.application.secret_key_base

    # Minimum length of the hash (default: 6)
    config.min_hash_length = 6

    # Custom alphabet (URL-safe, lowercase for consistency)
    config.alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
  end
RUBY

append_to_file '.env.development', "HASHID_SALT=development_salt_change_in_production\n"

say '✅ Public IDs configured!', :green
