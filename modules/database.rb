# frozen_string_literal: true

say 'Configuring PostgreSQL with multi-database setup...', :green

gem 'pg'

say '   Creating database.yml...', :cyan
file 'config/database.yml', <<~YAML, force: true
  # PostgreSQL for all environments (with Row Level Security support)
  # Ensure PostgreSQL is running locally for development
  default: &default
    adapter: postgresql
    encoding: unicode
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    prepared_statements: true
    advisory_locks: true
    url: <%= ENV['DATABASE_URL'] %>

  development:
    primary: &primary_development
      <<: *default
      database: #{app_name}_development
    queue:
      <<: *primary_development
      database: #{app_name}_queue_development
      migrations_paths: db/queue_migrate
    cache:
      <<: *primary_development
      database: #{app_name}_cache_development
      migrations_paths: db/cache_migrate
    cable:
      <<: *primary_development
      database: #{app_name}_cable_development
      migrations_paths: db/cable_migrate

  test:
    primary: &primary_test
      <<: *default
      database: #{app_name}_test
    queue:
      <<: *primary_test
      database: #{app_name}_queue_test
      migrations_paths: db/queue_migrate
    cache:
      <<: *primary_test
      database: #{app_name}_cache_test
      migrations_paths: db/cache_migrate
    cable:
      <<: *primary_test
      database: #{app_name}_cable_test
      migrations_paths: db/cable_migrate

  production:
    primary: &primary_production
      <<: *default
      database: #{app_name}_production
      username: #{app_name}
      password: <%= ENV["#{app_name.upcase}_DATABASE_PASSWORD"] %>
    queue:
      <<: *primary_production
      database: #{app_name}_queue_production
      migrations_paths: db/queue_migrate
    cache:
      <<: *primary_production
      database: #{app_name}_cache_production
      migrations_paths: db/cache_migrate
    cable:
      <<: *primary_production
      database: #{app_name}_cable_production
      migrations_paths: db/cable_migrate
YAML

say 'Database configuration complete!', :green
say '   Primary database: #{app_name}_[env]', :cyan
say '   Queue database: #{app_name}_queue_[env]', :cyan
say '   Cache database: #{app_name}_cache_[env]', :cyan
say '   Cable database: #{app_name}_cable_[env]', :cyan
