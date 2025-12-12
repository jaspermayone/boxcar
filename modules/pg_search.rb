# frozen_string_literal: true

say 'Setting up pg_search for PostgreSQL full-text search...', :green

gem 'pg_search'

after_bundle do
  say '   Running pg_search multisearch migration generator...', :cyan
  rails_command 'generate pg_search:migration:multisearch'
end

say '   Creating Searchable concern...', :cyan
file 'app/models/concerns/searchable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include this concern in models that need full-text search
  #
  # Usage:
  #   class Post < ApplicationRecord
  #     include Searchable
  #     searchable_by :title, :body
  #   end
  #
  #   Post.search("hello world")
  #
  # Advanced usage with weights:
  #   class Post < ApplicationRecord
  #     include Searchable
  #     searchable_by title: 'A', body: 'B', author_name: 'C'
  #   end
  #
  # With associations:
  #   class Post < ApplicationRecord
  #     include Searchable
  #     searchable_by :title, :body, associated: { comments: :content }
  #   end
  #
  module Searchable
    extend ActiveSupport::Concern

    included do
      include PgSearch::Model
    end

    class_methods do
      def searchable_by(*columns, associated: nil, **weighted_columns)
        tsearch_options = {
          prefix: true,
          dictionary: 'english',
          tsvector_column: 'searchable'
        }

        against = if weighted_columns.any?
          weighted_columns.transform_values { |weight| weight.to_sym }
        else
          columns
        end

        search_config = {
          against: against,
          using: {
            tsearch: tsearch_options
          }
        }

        if associated
          search_config[:associated_against] = associated
        end

        pg_search_scope :search, **search_config

        # Also add a ranked search that includes the rank
        pg_search_scope :search_with_rank, **search_config.merge(ranked_by: ':tsearch')
      end
    end
  end
RUBY

say '   Creating multisearch initializer...', :cyan
file 'config/initializers/pg_search.rb', <<~RUBY
  # frozen_string_literal: true

  PgSearch.multisearch_options = {
    using: {
      tsearch: {
        prefix: true,
        dictionary: 'english'
      }
    }
  }
RUBY

say '   Creating search generator...', :cyan
file 'lib/generators/search_index/search_index_generator.rb', <<~RUBY
  # frozen_string_literal: true

  class SearchIndexGenerator < Rails::Generators::NamedBase
    include Rails::Generators::Migration

    source_root File.expand_path('templates', __dir__)

    def self.next_migration_number(_dirname)
      Time.now.utc.strftime('%Y%m%d%H%M%S')
    end

    def create_migration_file
      migration_template 'migration.rb.erb', "db/migrate/add_search_index_to_\#{table_name}.rb"
    end

    private

    def table_name
      file_name.tableize
    end
  end
RUBY

file 'lib/generators/search_index/templates/migration.rb.erb', <<~ERB
  class AddSearchIndexTo<%= table_name.camelize %> < ActiveRecord::Migration[<%= Rails::VERSION::MAJOR %>.<%= Rails::VERSION::MINOR %>]
    def change
      add_column :<%= table_name %>, :searchable, :tsvector
      add_index :<%= table_name %>, :searchable, using: :gin

      # Uncomment and customize the trigger for automatic updates:
      # execute <<-SQL
      #   CREATE TRIGGER <%= table_name %>_searchable_update
      #   BEFORE INSERT OR UPDATE ON <%= table_name %>
      #   FOR EACH ROW EXECUTE FUNCTION
      #   tsvector_update_trigger(searchable, 'pg_catalog.english', title, body);
      # SQL
    end
  end
ERB

say 'pg_search configured!', :green
say '   Include `Searchable` in models and call `searchable_by :columns`', :cyan
say '   Generate index: rails g search_index ModelName', :cyan
say '   Search: Model.search("query")', :cyan
