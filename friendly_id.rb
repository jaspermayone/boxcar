# frozen_string_literal: true

say 'Setting up FriendlyId for slugs and permalinks...', :green

gem 'friendly_id'

after_bundle do
  say '   Running FriendlyId generator...', :cyan
  rails_command 'generate friendly_id'
end

say '   Creating Sluggable concern...', :cyan
file 'app/models/concerns/sluggable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include this concern in models that need URL slugs
  #
  # Migration:
  #   add_column :posts, :slug, :string
  #   add_index :posts, :slug, unique: true
  #
  # Usage:
  #   class Post < ApplicationRecord
  #     include Sluggable
  #     slugged_by :title
  #   end
  #
  #   post = Post.create(title: "Hello World")
  #   post.slug  # => "hello-world"
  #   Post.friendly.find("hello-world")
  #
  # With history (redirects old slugs):
  #   class Post < ApplicationRecord
  #     include Sluggable
  #     slugged_by :title, history: true
  #   end
  #
  module Sluggable
    extend ActiveSupport::Concern

    included do
      extend FriendlyId
    end

    class_methods do
      def slugged_by(attribute, history: false, scope: nil)
        options = { use: [:slugged] }
        options[:use] << :history if history
        options[:use] << :scoped if scope
        options[:scope] = scope if scope

        friendly_id attribute, **options
      end
    end
  end
RUBY

say 'FriendlyId configured!', :green
say '   Include `Sluggable` in models and call `slugged_by :attribute`', :cyan
say '   Add slug column: add_column :table, :slug, :string', :cyan
say '   Find records: Model.friendly.find(params[:id])', :cyan
