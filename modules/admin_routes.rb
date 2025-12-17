# frozen_string_literal: true

say 'Configuring admin routes...', :green

say '   Creating AdminConstraint for route protection...', :cyan
file 'app/constraints/admin_constraint.rb', <<~RUBY
  # frozen_string_literal: true

  class AdminConstraint
    def initialize(policy_method)
      @policy_method = policy_method
    end

    def matches?(request)
      token = request.cookie_jar.signed[:session_token]
      return false unless token

      session = Session.find_by(token: token)
      return false unless session&.user

      AdminPolicy.new(session.user, :admin).public_send(@policy_method)
    rescue StandardError
      false
    end
  end
RUBY

say '   Adding admin namespace routes...', :cyan
route <<~RUBY
  namespace :admin do
    root to: 'application#index'

    # Blazer BI Dashboard (admin or above)
    mount Blazer::Engine, at: 'blazer', constraints: AdminConstraint.new(:blazer?) if defined?(Blazer)

    # Flipper Feature Flags (super_admin or above)
    mount Flipper::UI.app(Flipper), at: 'flipper', constraints: AdminConstraint.new(:flipper?) if defined?(Flipper)

    # Rails Performance Dashboard (admin or above)
    mount RailsPerformance::Engine, at: 'performance', constraints: AdminConstraint.new(:rails_performance?) if defined?(RailsPerformance)

    # GoodJob Dashboard (admin or above)
    mount GoodJob::Engine, at: 'jobs', constraints: AdminConstraint.new(:jobs?) if defined?(GoodJob)

    # Console Audits (super_admin or above)
    mount Audits1984::Engine, at: 'console_audits', constraints: AdminConstraint.new(:console_audits?) if defined?(Audits1984)

    # PgHero PostgreSQL Dashboard (admin or above)
    mount PgHero::Engine, at: 'pghero', constraints: AdminConstraint.new(:pghero?) if defined?(PgHero)

    resources :users
  end
RUBY

say '   Adding health check routes...', :cyan
route <<~RUBY
  # Health checks (public endpoint)
  mount OkComputer::Engine, at: '/health' if defined?(OkComputer)
RUBY

say 'Admin routes configured!', :green
say '   Admin dashboard at /admin', :cyan
say '   Health checks at /health', :cyan
