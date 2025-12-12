# frozen_string_literal: true

say 'Setting up Kaminari for pagination...', :green

gem 'kaminari'

after_bundle do
  say '   Running Kaminari config generator...', :cyan
  rails_command 'generate kaminari:config'
end

say '   Creating Kaminari initializer...', :cyan
initializer 'kaminari.rb', <<~RUBY
  # frozen_string_literal: true

  Kaminari.configure do |config|
    config.default_per_page = 25
    config.max_per_page = 100
    config.window = 2
    config.outer_window = 1
    config.left = 0
    config.right = 0
    # config.page_method_name = :page
    # config.param_name = :page
    # config.max_pages = nil
    # config.params_on_first_page = false
  end
RUBY

say 'Kaminari pagination configured!', :green
say '   Usage: @users = User.page(params[:page]).per(25)', :cyan
say '   View helper: <%= paginate @users %>', :cyan
