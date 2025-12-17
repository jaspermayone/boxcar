# frozen_string_literal: true

say 'Setting up Solid Queue for background processing...', :green

gem 'solid_queue'
gem 'mission_control-jobs'

say '   Configuring Solid Queue...', :cyan
initializer 'solid_queue.rb', <<~RUBY
  # frozen_string_literal: true

  Rails.application.configure do
    # Use Solid Queue as the Active Job adapter
    config.active_job.queue_adapter = :solid_queue

    # Solid Queue uses PostgreSQL for job storage
    # Configuration is in config/solid_queue.yml
  end
RUBY

after_bundle do
  say '   Installing Solid Queue...', :cyan
  rails_command 'solid_queue:install'

  say '   Adding Solid Queue to Procfile.dev...', :cyan
  # Ensure Procfile.dev exists and has the worker line
  if File.exist?('Procfile.dev')
    append_to_file 'Procfile.dev', "worker: bin/rails solid_queue:start\n"
  else
    create_file 'Procfile.dev', <<~PROCFILE
      web: bin/rails server
      css: bin/rails tailwindcss:watch
      worker: bin/rails solid_queue:start
    PROCFILE
  end
end

say 'Solid Queue configured!', :green
say '   Run jobs: bin/rails solid_queue:start', :cyan
