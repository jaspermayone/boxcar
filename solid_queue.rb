# frozen_string_literal: true

say 'Setting up Solid Queue for background jobs...', :green

gem 'solid_queue'
gem 'mission_control-jobs'

after_bundle do
  say '   Running Solid Queue installer...', :cyan
  rails_command 'generate solid_queue:install'

  say '   Creating queue database...', :cyan
  rails_command 'db:create:queue'

  say '   Loading Solid Queue schema...', :cyan
  rails_command 'db:schema:load:queue'
end

say '   Creating Solid Queue initializer...', :cyan
file 'config/initializers/solid_queue.rb', <<~RUBY
  # frozen_string_literal: true

  # Solid Queue Configuration
  # https://github.com/rails/solid_queue
  #
  # Database-backed Active Job backend that uses PostgreSQL for job storage.
  # No need for Redis or external dependencies.

  Rails.application.config.solid_queue.tap do |config|
    # Silence polling queries in logs
    config.silence_polling = true

    # How often to check for new jobs (default: 0.1 seconds)
    # config.polling_interval = 0.1

    # Number of threads per worker (default: 3)
    # config.workers_per_process = 3

    # Concurrency per queue
    # config.concurrency_maintenance_interval = 600
  end
RUBY

say '   Configuring Active Job to use Solid Queue...', :cyan
inject_into_file 'config/application.rb', after: "class Application < Rails::Application\n" do
  "    config.active_job.queue_adapter = :solid_queue\n"
end

say '   Creating Procfile.dev entry...', :cyan
append_to_file 'Procfile.dev', "jobs: bundle exec rake solid_queue:start\n"

say 'Solid Queue configured!', :green
say '   Dashboard at /admin/jobs (admin only)', :cyan
say '   Jobs will be processed via: bin/jobs or rake solid_queue:start', :cyan
say '   Run migrations: rails db:migrate', :yellow
say '   Configure queues in config/solid_queue.yml', :cyan
