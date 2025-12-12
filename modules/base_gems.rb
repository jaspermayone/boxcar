# frozen_string_literal: true

say 'Installing base gems...', :green

gem 'jb'              # Fast JSON templates
gem 'awesome_print'   # Pretty print objects
gem 'faraday'         # HTTP client

gem 'dotenv-rails', groups: %i[development test]

file '.env.development', ''

# Remove default allow_browser restriction
gsub_file 'app/controllers/application_controller.rb',
          /^\s*# Only allow modern browsers.*\n\s*allow_browser versions: :modern\n?/m,
          ''

say 'Base gems installed!', :green
