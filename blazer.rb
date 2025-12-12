# frozen_string_literal: true

say 'Setting up Blazer for BI dashboard...', :green

gem 'blazer'

after_bundle do
  say '   Running Blazer install...', :cyan
  rails_command 'generate blazer:install'
end

say '   Creating Blazer initializer...', :cyan
file 'config/initializers/blazer.rb', <<~RUBY
  # frozen_string_literal: true

  # Blazer configuration is in config/blazer.yml
  # This file handles additional Ruby-based config

  # Ensure Blazer uses the correct database
  # Blazer.settings["data_sources"]["main"]["url"] = ENV["DATABASE_URL"]
RUBY

say '   Creating Blazer config...', :cyan
file 'config/blazer.yml', <<~YAML
  # Blazer configuration
  # https://github.com/ankane/blazer

  data_sources:
    main:
      url: <%= ENV["DATABASE_URL"] %>

      # Statement timeout (in seconds)
      timeout: 15

      # Caching (requires cache store)
      cache:
        mode: slow  # or "all"
        expires_in: 60  # seconds

      # Smart variables (dropdown filters in queries)
      smart_variables:
        user_id: "SELECT id, email FROM users ORDER BY email"
        # state: "SELECT DISTINCT state FROM orders"

      # Linked columns (make values clickable)
      linked_columns:
        user_id: "/admin/users/{value}"
        # order_id: "/admin/orders/{value}"

      # Smart columns (format output)
      smart_columns:
        created_at: datetime
        updated_at: datetime
        # amount: currency

  # Audit logging
  audit: true

  # Check queries for anomalies
  check_schedules:
    - "1 day"
    - "1 week"
    - "1 month"
YAML

say 'Blazer BI dashboard configured!', :green
say '   Access at /admin/blazer (admin only)', :cyan
say '   Run migrations: rails db:migrate', :yellow
say '   Configure data sources in config/blazer.yml', :cyan
