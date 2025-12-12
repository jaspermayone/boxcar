# frozen_string_literal: true

say 'Setting up soft deletes with acts_as_paranoid...', :green

gem 'acts_as_paranoid'

say '   Creating SoftDeletable concern...', :cyan
file 'app/models/concerns/soft_deletable.rb', <<~RUBY
  # frozen_string_literal: true

  # Include this concern in models that should support soft deletes
  #
  # Migration:
  #   add_column :posts, :deleted_at, :datetime
  #   add_index :posts, :deleted_at
  #
  # Usage:
  #   class Post < ApplicationRecord
  #     include SoftDeletable
  #   end
  #
  #   post.destroy          # soft deletes (sets deleted_at)
  #   post.deleted?         # => true
  #   post.recover          # restores the record
  #   post.destroy_fully!   # permanently deletes
  #
  #   Post.all              # excludes soft-deleted records
  #   Post.with_deleted     # includes soft-deleted records
  #   Post.only_deleted     # only soft-deleted records
  #
  module SoftDeletable
    extend ActiveSupport::Concern

    included do
      acts_as_paranoid
    end

    # Permanently delete the record
    def destroy_fully!
      destroy_fully
    end
  end
RUBY

say '   Creating migration generator helper...', :cyan
file 'lib/generators/soft_delete/soft_delete_generator.rb', <<~RUBY
  # frozen_string_literal: true

  class SoftDeleteGenerator < Rails::Generators::NamedBase
    include Rails::Generators::Migration

    source_root File.expand_path('templates', __dir__)

    def self.next_migration_number(_dirname)
      Time.now.utc.strftime('%Y%m%d%H%M%S')
    end

    def create_migration_file
      migration_template 'migration.rb.erb', "db/migrate/add_deleted_at_to_\#{table_name}.rb"
    end

    private

    def table_name
      file_name.tableize
    end
  end
RUBY

file 'lib/generators/soft_delete/templates/migration.rb.erb', <<~ERB
  class AddDeletedAtTo<%= table_name.camelize %> < ActiveRecord::Migration[<%= Rails::VERSION::MAJOR %>.<%= Rails::VERSION::MINOR %>]
    def change
      add_column :<%= table_name %>, :deleted_at, :datetime
      add_index :<%= table_name %>, :deleted_at
    end
  end
ERB

say 'Soft deletes configured!', :green
say '   Include `SoftDeletable` in models', :cyan
say '   Generate migration: rails g soft_delete ModelName', :cyan
say '   Or manually: add_column :table, :deleted_at, :datetime', :cyan
