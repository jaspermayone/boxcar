# frozen_string_literal: true

say 'Installing development tools...', :green

# Development and debugging gems
gem_group :development do
  gem 'pry-rails'
  gem 'bullet'
  gem 'query_count'
  gem 'actual_db_schema'
  gem 'annotaterb'
  gem 'letter_opener_web'
end

# Bullet configuration for N+1 query detection
initializer 'bullet.rb', <<~RUBY
  # frozen_string_literal: true

  if defined?(Bullet) && Rails.env.development?
    Rails.application.configure do
      config.after_initialize do
        Bullet.enable = true
        Bullet.alert = false
        Bullet.bullet_logger = true
        Bullet.console = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
      end
    end
  end
RUBY

# Letter Opener Web for email preview in development
route <<~RUBY
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/letter_opener'
  end
RUBY

inject_into_file 'config/environments/development.rb', before: /^end$/ do
  <<~RUBY

  # Use letter_opener for email delivery
  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  RUBY
end

# Run generators after bundle
after_bundle do
  say '   Running AnnotateRb installer...', :cyan
  rails_command 'generate annotate_rb:install'

  say '   Running Bullet installer...', :cyan
  rails_command 'generate bullet:install'
end

say 'Development tools installed!', :green
