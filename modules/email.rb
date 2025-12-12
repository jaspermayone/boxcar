# frozen_string_literal: true

say 'Setting up email infrastructure...', :green

gem 'premailer-rails' # Inline CSS for email clients

say '   Configuring Premailer...', :cyan
initializer 'premailer.rb', <<~RUBY
  # frozen_string_literal: true

  Premailer::Rails.config.merge!(
    preserve_styles: true,
    remove_ids: false,
    remove_classes: false
  )
RUBY

say '   Creating UserMailer...', :cyan
file 'app/mailers/user_mailer.rb', <<~RUBY
  # frozen_string_literal: true

  class UserMailer < ApplicationMailer
    def welcome(user)
      @user = user
      @login_url = sign_in_url

      mail(
        to: @user.email,
        subject: "Welcome to \#{Rails.application.class.module_parent_name}"
      )
    end

    def password_reset(user, token)
      @user = user
      @token = token
      @reset_url = edit_password_reset_url(token: @token)

      mail(
        to: @user.email,
        subject: 'Reset your password'
      )
    end

    def email_confirmation(user, token)
      @user = user
      @token = token
      @confirm_url = confirm_email_url(token: @token)

      mail(
        to: @user.email,
        subject: 'Confirm your email address'
      )
    end
  end
RUBY

say '   Creating email layout...', :cyan
file 'app/views/layouts/mailer.html.erb', <<~ERB, force: true
  <!DOCTYPE html>
  <html>
    <head>
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        /* Base styles */
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
          font-size: 16px;
          line-height: 1.5;
          color: #333333;
          background-color: #f5f5f5;
          margin: 0;
          padding: 0;
        }

        /* Email container */
        .email-wrapper {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }

        .email-content {
          background-color: #ffffff;
          border-radius: 8px;
          padding: 40px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        /* Header */
        .email-header {
          text-align: center;
          margin-bottom: 30px;
        }

        .email-header h1 {
          margin: 0;
          font-size: 24px;
          color: #111111;
        }

        /* Body */
        .email-body {
          margin-bottom: 30px;
        }

        .email-body p {
          margin: 0 0 16px 0;
        }

        /* Button */
        .button {
          display: inline-block;
          padding: 12px 24px;
          background-color: #2563eb;
          color: #ffffff !important;
          text-decoration: none;
          border-radius: 6px;
          font-weight: 600;
        }

        .button:hover {
          background-color: #1d4ed8;
        }

        /* Footer */
        .email-footer {
          text-align: center;
          font-size: 14px;
          color: #666666;
          border-top: 1px solid #eeeeee;
          padding-top: 20px;
          margin-top: 30px;
        }

        .email-footer a {
          color: #2563eb;
        }
      </style>
    </head>
    <body>
      <div class="email-wrapper">
        <div class="email-content">
          <%= yield %>
        </div>
        <div class="email-footer">
          <p>&copy; <%= Date.current.year %> <%= Rails.application.class.module_parent_name %>. All rights reserved.</p>
          <p>
            <% if @user.respond_to?(:email) %>
              <a href="<%= mailkick_unsubscribe_url %>">Unsubscribe</a>
            <% end %>
          </p>
        </div>
      </div>
    </body>
  </html>
ERB

say '   Creating welcome email template...', :cyan
file 'app/views/user_mailer/welcome.html.erb', <<~ERB
  <div class="email-header">
    <h1>Welcome!</h1>
  </div>

  <div class="email-body">
    <p>Hi <%= @user.email %>,</p>

    <p>Thanks for signing up! We're excited to have you on board.</p>

    <p>To get started, click the button below to sign in to your account:</p>

    <p style="text-align: center; margin: 30px 0;">
      <a href="<%= @login_url %>" class="button">Sign In</a>
    </p>

    <p>If you have any questions, just reply to this email - we're always happy to help.</p>
  </div>
ERB

say '   Creating password reset template...', :cyan
file 'app/views/user_mailer/password_reset.html.erb', <<~ERB
  <div class="email-header">
    <h1>Reset Your Password</h1>
  </div>

  <div class="email-body">
    <p>Hi <%= @user.email %>,</p>

    <p>We received a request to reset your password. Click the button below to choose a new one:</p>

    <p style="text-align: center; margin: 30px 0;">
      <a href="<%= @reset_url %>" class="button">Reset Password</a>
    </p>

    <p>This link will expire in 2 hours.</p>

    <p>If you didn't request this, you can safely ignore this email. Your password won't be changed.</p>
  </div>
ERB

say '   Creating email confirmation template...', :cyan
file 'app/views/user_mailer/email_confirmation.html.erb', <<~ERB
  <div class="email-header">
    <h1>Confirm Your Email</h1>
  </div>

  <div class="email-body">
    <p>Hi <%= @user.email %>,</p>

    <p>Please confirm your email address by clicking the button below:</p>

    <p style="text-align: center; margin: 30px 0;">
      <a href="<%= @confirm_url %>" class="button">Confirm Email</a>
    </p>

    <p>This link will expire in 24 hours.</p>

    <p>If you didn't create an account, you can safely ignore this email.</p>
  </div>
ERB

say '   Creating text email templates...', :cyan
file 'app/views/user_mailer/welcome.text.erb', <<~ERB
  Welcome!

  Hi <%= @user.email %>,

  Thanks for signing up! We're excited to have you on board.

  To get started, visit: <%= @login_url %>

  If you have any questions, just reply to this email.
ERB

file 'app/views/user_mailer/password_reset.text.erb', <<~ERB
  Reset Your Password

  Hi <%= @user.email %>,

  We received a request to reset your password. Visit the link below to choose a new one:

  <%= @reset_url %>

  This link will expire in 2 hours.

  If you didn't request this, you can safely ignore this email.
ERB

file 'app/views/user_mailer/email_confirmation.text.erb', <<~ERB
  Confirm Your Email

  Hi <%= @user.email %>,

  Please confirm your email address by visiting:

  <%= @confirm_url %>

  This link will expire in 24 hours.
ERB

say '   Creating email previews...', :cyan
file 'test/mailers/previews/user_mailer_preview.rb', <<~RUBY
  # frozen_string_literal: true

  # Preview emails at http://localhost:3000/rails/mailers/user_mailer
  class UserMailerPreview < ActionMailer::Preview
    def welcome
      user = User.first || OpenStruct.new(email: 'user@example.com')
      UserMailer.welcome(user)
    end

    def password_reset
      user = User.first || OpenStruct.new(email: 'user@example.com')
      UserMailer.password_reset(user, 'sample_token_123')
    end

    def email_confirmation
      user = User.first || OpenStruct.new(email: 'user@example.com')
      UserMailer.email_confirmation(user, 'sample_token_123')
    end
  end
RUBY

say 'Email infrastructure configured!', :green
say '   Preview emails at /rails/mailers in development', :cyan
say '   Or use LetterOpener at /letter_opener', :cyan
