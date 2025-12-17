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
  # Ensure Procfile.dev exists and has the worker line (without duplicates)
  worker_line = "worker: bin/rails solid_queue:start\n"
  if File.exist?('Procfile.dev')
    content = File.read('Procfile.dev')
    unless content.include?('solid_queue:start')
      append_to_file 'Procfile.dev', worker_line
    end
  else
    # Procfile.dev doesn't exist yet - this is unusual since tailwindcss:install should create it
    # Create with just the worker line; web and css should already be configured by tailwind module
    create_file 'Procfile.dev', worker_line
  end
end

say 'Solid Queue configured!', :green
say '   Run jobs: bin/rails solid_queue:start', :cyan
