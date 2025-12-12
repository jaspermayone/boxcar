# frozen_string_literal: true

say 'Setting up Paper Trail for audit logging...', :green

gem 'paper_trail'

say '   Creating initializer...', :cyan
file 'config/initializers/paper_trail.rb', <<~RUBY
  PaperTrail.config.enabled = true
  PaperTrail.config.has_paper_trail_defaults = {
    on: %i[create update destroy]
  }
  PaperTrail.config.version_limit = nil
RUBY

say '   Creating Auditable concern...', :cyan
file 'app/models/concerns/auditable.rb', <<~RUBY
  # frozen_string_literal: true

  module Auditable
    extend ActiveSupport::Concern

    included do
      has_paper_trail
    end

    def audit_trail
      versions.order(created_at: :desc)
    end

    def last_modified_by
      versions.last&.whodunnit
    end
  end
RUBY

say '   Setting up whodunnit tracking...', :cyan
file 'app/controllers/concerns/set_paper_trail_whodunnit.rb', <<~RUBY
  # frozen_string_literal: true

  module SetPaperTrailWhodunnit
    extend ActiveSupport::Concern

    included do
      before_action :set_paper_trail_whodunnit
    end

    private

    def user_for_paper_trail
      current_user&.id&.to_s || 'system'
    end
  end
RUBY

say '   Adding to ApplicationController...', :cyan
inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', <<~RUBY
  include SetPaperTrailWhodunnit
RUBY

after_bundle do
  say '   Running Paper Trail install generator...', :cyan
  rails_command 'generate paper_trail:install'
end

say 'Paper Trail audit logging configured!', :green
say '   Include `Auditable` in models you want to track', :cyan
