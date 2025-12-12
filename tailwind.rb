# frozen_string_literal: true

say '🎨 Setting up Tailwind CSS...', :green

after_bundle do
  say '   Installing Tailwind...', :cyan
  rails_command 'tailwindcss:install'
  say '✅ Tailwind CSS configured!', :green
end