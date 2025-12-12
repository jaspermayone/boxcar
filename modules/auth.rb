# frozen_string_literal: true

say 'Setting up custom authentication...', :green
say '   Adding bcrypt gem...', :cyan

gem 'bcrypt', '~> 3.1'

# Generate models after bundle install
after_bundle do
  say '   Generating User model...', :cyan
  generate :model, 'User email:string:uniq password_digest:string role:integer'

  say '   Generating Session model...', :cyan
  generate :model, 'Session user:references token:string:uniq ip_address:string user_agent:string'
end

# User model with has_secure_password and roles
file 'app/models/user.rb', <<~RUBY, force: true
  class User < ApplicationRecord
    include PublicIdentifiable
    set_public_id_prefix :usr

    has_secure_password

    enum :role, { user: 0, admin: 1, super_admin: 2, owner: 3 }, default: :user

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true,
                      uniqueness: { case_sensitive: false },
                      format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 8 }, if: -> { password.present? }
    validates :role, presence: true

    # Helper method to check if user has any admin access
    def admin_or_above?
      admin? || super_admin? || owner?
    end

    # Helper method to check if user has super admin or owner access
    def super_admin_or_above?
      super_admin? || owner?
    end
  end
RUBY

file 'app/models/session.rb', <<~RUBY, force: true
  class Session < ApplicationRecord
    belongs_to :user

    before_create :generate_token

    validates :token, presence: true, uniqueness: true

    private

    def generate_token
      self.token = SecureRandom.urlsafe_base64(32)
    end
  end
RUBY

say '   Creating Current model...', :cyan
file 'app/models/current.rb', <<~RUBY
  class Current < ActiveSupport::CurrentAttributes
    attribute :session, :user

    delegate :user, to: :session, allow_nil: true
  end
RUBY

say '   Creating Authentication concern...', :cyan
file 'app/controllers/concerns/authentication.rb', <<~RUBY
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate
      helper_method :signed_in?, :current_user
    end

    private

    def authenticate
      if (session_record = find_session_by_cookie)
        Current.session = session_record
      end
    end

    def require_authentication
      redirect_to sign_in_path, alert: 'Please sign in to continue.' unless signed_in?
    end

    def require_admin
      require_authentication
      return if current_user&.admin_or_above?

      redirect_to root_path, alert: 'You are not authorized to access this page.'
    end

    def require_super_admin
      require_authentication
      return if current_user&.super_admin?

      redirect_to root_path, alert: 'You are not authorized to access this page.'
    end

    def signed_in?
      Current.session.present?
    end

    def current_user
      Current.user
    end

    def find_session_by_cookie
      Session.find_by(token: cookies.signed[:session_token])
    end

    def start_session(user)
      session_record = user.sessions.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      cookies.signed.permanent[:session_token] = {
        value: session_record.token,
        httponly: true,
        same_site: :lax
      }
      Current.session = session_record
    end

    def end_session
      Current.session&.destroy
      cookies.delete(:session_token)
    end
  end
RUBY

say '   Adding to ApplicationController...', :cyan
inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', <<~RUBY
  include Authentication
RUBY

say '   Creating SessionsController...', :cyan
file 'app/controllers/sessions_controller.rb', <<~RUBY
  class SessionsController < ApplicationController
    skip_before_action :authenticate, only: %i[new create]

    def new
      redirect_to root_path if signed_in?
    end

    def create
      if (user = User.find_by(email: params[:email])&.authenticate(params[:password]))
        start_session(user)
        redirect_to root_path, notice: 'Signed in successfully.'
      else
        flash.now[:alert] = 'Invalid email or password.'
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      end_session
      redirect_to root_path, notice: 'Signed out successfully.'
    end
  end
RUBY

say '   Creating RegistrationsController...', :cyan
file 'app/controllers/registrations_controller.rb', <<~RUBY
  class RegistrationsController < ApplicationController
    skip_before_action :authenticate, only: %i[new create]

    def new
      redirect_to root_path if signed_in?
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        start_session(@user)
        redirect_to root_path, notice: 'Account created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end
  end
RUBY

say '   Creating sign in view...', :cyan
file 'app/views/sessions/new.html.erb', <<~ERB
  <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
      <div>
        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
          Sign in to your account
        </h2>
        <p class="mt-2 text-center text-sm text-gray-600">
          Or
          <%= link_to 'create a new account', sign_up_path, class: 'font-medium text-canopy-green hover:text-fresh-leaf' %>
        </p>
      </div>

      <%= form_with url: sign_in_path, class: 'mt-8 space-y-6' do |f| %>
        <div class="rounded-md shadow-sm -space-y-px">
          <div>
            <%= f.label :email, class: 'sr-only' %>
            <%= f.email_field :email, required: true, autofocus: true, autocomplete: 'email',
                placeholder: 'Email address',
                class: 'appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-canopy-green focus:border-canopy-green focus:z-10 sm:text-sm' %>
          </div>
          <div>
            <%= f.label :password, class: 'sr-only' %>
            <%= f.password_field :password, required: true, autocomplete: 'current-password',
                placeholder: 'Password',
                class: 'appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-canopy-green focus:border-canopy-green focus:z-10 sm:text-sm' %>
          </div>
        </div>

        <div>
          <%= f.submit 'Sign in',
              class: 'group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-canopy-green hover:bg-bamboo-shadow focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-canopy-green cursor-pointer' %>
        </div>
      <% end %>
    </div>
  </div>
ERB

say '   Creating sign up view...', :cyan
file 'app/views/registrations/new.html.erb', <<~ERB
  <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
      <div>
        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
          Create your account
        </h2>
        <p class="mt-2 text-center text-sm text-gray-600">
          Already have an account?
          <%= link_to 'Sign in', sign_in_path, class: 'font-medium text-canopy-green hover:text-fresh-leaf' %>
        </p>
      </div>

      <%= form_with model: @user, url: sign_up_path, class: 'mt-8 space-y-6' do |f| %>
        <% if @user.errors.any? %>
          <div class="rounded-md bg-red-50 p-4">
            <div class="text-sm text-red-700">
              <ul class="list-disc pl-5 space-y-1">
                <% @user.errors.full_messages.each do |message| %>
                  <li><%= message %></li>
                <% end %>
              </ul>
            </div>
          </div>
        <% end %>

        <div class="rounded-md shadow-sm -space-y-px">
          <div>
            <%= f.label :email, class: 'sr-only' %>
            <%= f.email_field :email, required: true, autofocus: true, autocomplete: 'email',
                placeholder: 'Email address',
                class: 'appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-canopy-green focus:border-canopy-green focus:z-10 sm:text-sm' %>
          </div>
          <div>
            <%= f.label :password, class: 'sr-only' %>
            <%= f.password_field :password, required: true, autocomplete: 'new-password',
                placeholder: 'Password (min 8 characters)',
                class: 'appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-canopy-green focus:border-canopy-green focus:z-10 sm:text-sm' %>
          </div>
          <div>
            <%= f.label :password_confirmation, class: 'sr-only' %>
            <%= f.password_field :password_confirmation, required: true, autocomplete: 'new-password',
                placeholder: 'Confirm password',
                class: 'appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-canopy-green focus:border-canopy-green focus:z-10 sm:text-sm' %>
          </div>
        </div>

        <div>
          <%= f.submit 'Create account',
              class: 'group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-canopy-green hover:bg-bamboo-shadow focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-canopy-green cursor-pointer' %>
        </div>
      <% end %>
    </div>
  </div>
ERB

say '   Adding routes...', :cyan
route <<~RUBY
  # Authentication
  get 'sign_in', to: 'sessions#new'
  post 'sign_in', to: 'sessions#create'
  delete 'sign_out', to: 'sessions#destroy'
  get 'sign_up', to: 'registrations#new'
  post 'sign_up', to: 'registrations#create'
RUBY

say '   Creating Admin namespace...', :cyan
file 'app/controllers/admin/application_controller.rb', <<~RUBY
  # frozen_string_literal: true

  module Admin
    class ApplicationController < ::ApplicationController
      before_action :require_admin

      def index
        @current_user = current_user
      end

      private

      def require_admin
        unless current_user&.admin_or_above?
          redirect_to root_path, alert: 'You are not authorized to access this area.'
        end
      end
    end
  end
RUBY

file 'app/controllers/admin/users_controller.rb', <<~RUBY
  # frozen_string_literal: true

  module Admin
    class UsersController < Admin::ApplicationController
      before_action :set_user, only: %i[show edit update destroy]

      def index
        @users = User.all
      end

      def show; end

      def edit; end

      def update
        if @user.update(user_params)
          redirect_to admin_user_path(@user), notice: 'User updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @user.destroy
        redirect_to admin_users_path, notice: 'User deleted successfully.'
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:email, :role)
      end
    end
  end
RUBY

say 'Custom authentication setup complete!', :green
