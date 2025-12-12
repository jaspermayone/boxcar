# frozen_string_literal: true

say 'Setting up Mailkick for email unsubscribes...', :green

gem 'mailkick'

after_bundle do
  say '   Running Mailkick installer...', :cyan
  rails_command 'generate mailkick:install'

  say '   Running Mailkick views generator...', :cyan
  rails_command 'generate mailkick:views'
end

say '   Creating Mailkick initializer...', :cyan
initializer 'mailkick.rb', <<~RUBY
  # frozen_string_literal: true

  # Mailkick - Email unsubscribe management
  # https://github.com/ankane/mailkick

  Mailkick.secret_token = Rails.application.credentials.dig(:mailkick, :secret_token) ||
                          Rails.application.secret_key_base

  # Optional: Use a custom method to check opt-outs
  # Mailkick.user_method = ->(email) { User.find_by(email: email) }
RUBY

say '   Adding Mailkick to User model...', :cyan
inject_into_file 'app/models/user.rb', after: "class User < ApplicationRecord\n" do
  "  has_subscriptions\n"
end

say 'Mailkick configured!', :green
say '   Users can unsubscribe via: mailkick_unsubscribe_url(user)', :cyan
say '   Check opt-out: user.opted_out_of_emails?', :cyan
