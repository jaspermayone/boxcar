# frozen_string_literal: true

say 'Setting up PgHero...', :green

gem 'pghero'

say '   Configuring PgHero...', :cyan
initializer 'pghero.rb', <<~RUBY
  # frozen_string_literal: true

  # PgHero - PostgreSQL insights
  # Dashboard: /admin/pghero

  ENV['PGHERO_USERNAME'] ||= Rails.application.credentials.dig(:pghero, :username) || 'admin'
  ENV['PGHERO_PASSWORD'] ||= Rails.application.credentials.dig(:pghero, :password) || 'admin'
RUBY

after_bundle do
  say '   Generating PgHero config...', :cyan
  rails_command 'generate pghero:config'

  say '   Generating PgHero query stats migration...', :cyan
  rails_command 'generate pghero:query_stats'
end

say 'PgHero configured!', :green
say '   Dashboard will be mounted at /admin/pghero', :cyan
say '   Enable pg_stat_statements in PostgreSQL for query insights', :yellow
