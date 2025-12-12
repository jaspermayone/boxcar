# frozen_string_literal: true

say 'Setting up Console1984 for console access auditing...', :green

gem 'console1984'
gem 'audits1984'

after_bundle do
  say '   Running Console1984 installer...', :cyan
  rails_command 'console1984:install'

  say '   Running Audits1984 installer...', :cyan
  rails_command 'audits1984:install'
end

say '   Creating Console1984 initializer...', :cyan
file 'config/initializers/console1984.rb', <<~RUBY
  # frozen_string_literal: true

  Console1984.config do |config|
    # Require a reason for console access
    config.ask_for_session_reason = true

    # Protected URLs that will be flagged when accessed
    config.protected_urls = [
      %r{/admin},
      %r{/users/\\d+}
    ]

    # Protected environments (production by default)
    config.protected_environments = %i[production]

    # Incinerate console sessions after this period
    config.incinerate_after = 30.days

    # Enable/disable encryption of console commands
    config.encrypt_session_data = true
  end
RUBY

say '   Creating AuditsAuthController...', :cyan
file 'app/controllers/audits_auth_controller.rb', <<~RUBY
  # frozen_string_literal: true

  class AuditsAuthController < ApplicationController
    before_action :require_super_admin
  end
RUBY

say '   Creating Audits1984 initializer...', :cyan
file 'config/initializers/audits1984.rb', <<~RUBY
  # frozen_string_literal: true

  Audits1984.auditor_class = 'User'
  Audits1984.base_controller_class = 'AuditsAuthController'
RUBY

say 'Console1984 + Audits1984 configured!', :green
say '   - Console sessions are logged and encrypted', :cyan
say '   - Access audit logs at /admin/console_audits', :cyan
say '   - Only super_admins can review sessions', :cyan
say '   Run migrations: rails db:migrate', :yellow
