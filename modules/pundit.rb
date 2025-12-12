# frozen_string_literal: true

say 'Setting up Pundit for authorization...', :green

gem 'pundit'

after_bundle do
  say '   Running Pundit installer...', :cyan
  rails_command 'generate pundit:install'
end

say '   Creating ApplicationPolicy...', :cyan
file 'app/policies/application_policy.rb', <<~RUBY
  # frozen_string_literal: true

  class ApplicationPolicy
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def index?
      false
    end

    def show?
      false
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      false
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    class Scope
      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        raise NoMethodError, "You must define #resolve in \#{self.class}"
      end

      private

      attr_reader :user, :scope
    end
  end
RUBY

say '   Creating example UserPolicy...', :cyan
file 'app/policies/user_policy.rb', <<~RUBY
  # frozen_string_literal: true

  class UserPolicy < ApplicationPolicy
    def show?
      user == record
    end

    def update?
      user == record
    end

    def destroy?
      user == record
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(id: user.id)
      end
    end
  end
RUBY

say '   Creating AdminPolicy...', :cyan
file 'app/policies/admin_policy.rb', <<~RUBY
  # frozen_string_literal: true

  class AdminPolicy < ApplicationPolicy
    def blazer?
      user&.admin_or_above?
    end

    def flipper?
      user&.super_admin_or_above?
    end

    def rails_performance?
      user&.admin_or_above?
    end

    def jobs?
      user&.admin_or_above?
    end

    def console_audits?
      user&.super_admin_or_above?
    end

    def pghero?
      user&.admin_or_above?
    end

    def access_admin_endpoints?
      user&.admin_or_above?
    end
  end
RUBY

say '   Creating DefaultPolicy...', :cyan
file 'app/policies/default_policy.rb', <<~RUBY
  # frozen_string_literal: true

  # Default policy for records without a specific policy
  # Used when Pundit cannot find a policy for a given record
  class DefaultPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present?
    end

    def create?
      user.present?
    end

    def update?
      user.present? && (user == record_owner || user.admin_or_above?)
    end

    def destroy?
      user.present? && (user == record_owner || user.admin_or_above?)
    end

    private

    def record_owner
      record.respond_to?(:user) ? record.user : nil
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user&.admin_or_above?
          scope.all
        else
          scope.none
        end
      end
    end
  end
RUBY

say '   Adding Pundit to ApplicationController...', :cyan
inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', <<~RUBY
  include Pundit::Authorization
  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = 'You are not authorized to perform this action.'
    redirect_back(fallback_location: root_path)
  end

  def skip_pundit?
    devise_controller? rescue false || self.class.to_s.start_with?('Sessions', 'Registrations')
  end
RUBY

say 'Pundit authorization configured!', :green
say '   Create policies in app/policies/ for each model', :cyan
say '   Use `authorize @record` in controller actions', :cyan
say '   Use `policy_scope(Model)` for index queries', :cyan
