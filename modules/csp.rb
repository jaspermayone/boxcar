# frozen_string_literal: true

say 'Setting up security hardening...', :green

gem 'rack-cors'
# bundler-audit included by Rails 8

say '   Content Security Policy disabled by default (can be enabled in initializer)...', :cyan
initializer 'content_security_policy.rb', <<~RUBY
  # frozen_string_literal: true

  # Content Security Policy (CSP) is disabled by default for flexibility.
  # Uncomment and configure the policy below if you need stricter security controls.
  # See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

  # Rails.application.configure do
  #   config.content_security_policy do |policy|
  #     policy.default_src :self
  #     policy.font_src    :self, :data, 'https://fonts.gstatic.com'
  #     policy.img_src     :self, :data, :blob
  #     policy.object_src  :none
  #     policy.script_src  :self
  #     policy.style_src   :self, :unsafe_inline, 'https://fonts.googleapis.com'
  #     policy.frame_ancestors :self
  #     policy.base_uri    :self
  #     policy.form_action :self
  #
  #     # Allow connections to same origin and websockets
  #     policy.connect_src :self, :wss
  #
  #     # Report violations to your error tracking service
  #     # policy.report_uri '/csp-report'
  #   end
  #
  #   # Generate nonce for inline scripts/styles
  #   # Use <%= csp_meta_tag %> in your layout and
  #   # <%= javascript_tag nonce: true %> for inline scripts
  #   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  #   config.content_security_policy_nonce_directives = %w[script-src style-src]
  #
  #   # Report CSP violations without enforcing (useful for rollout)
  #   # config.content_security_policy_report_only = true
  # end
RUBY

say '   Configuring CORS...', :cyan
initializer 'cors.rb', <<~RUBY
  # frozen_string_literal: true

  # Configure Cross-Origin Resource Sharing (CORS)
  # See: https://github.com/cyu/rack-cors

  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      # Allow requests from your frontend domain
      origins Rails.env.development? ? 'localhost:3000' : ENV.fetch('CORS_ORIGINS', '').split(',')

      resource '/api/*',
               headers: :any,
               methods: %i[get post put patch delete options head],
               credentials: true,
               max_age: 86_400

      # Health checks should be accessible
      resource '/health*',
               headers: :any,
               methods: [:get]
    end
  end
RUBY

say '   Adding security headers...', :cyan
initializer 'secure_headers.rb', <<~RUBY
  # frozen_string_literal: true

  # Additional security headers configured via middleware
  Rails.application.config.action_dispatch.default_headers = {
    'X-Frame-Options' => 'SAMEORIGIN',
    'X-Content-Type-Options' => 'nosniff',
    'X-XSS-Protection' => '0', # Disabled as per modern best practices
    'X-Permitted-Cross-Domain-Policies' => 'none',
    'Referrer-Policy' => 'strict-origin-when-cross-origin',
    'Permissions-Policy' => 'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()'
  }
RUBY

say '   Skipping CSP meta tag...', :cyan
# CSP meta tag is not added since CSP is disabled by default
# Uncomment below if you enable CSP in the initializer
# inject_into_file 'app/views/layouts/application.html.erb', after: "<%= csrf_meta_tags %>\n" do
#   "    <%= csp_meta_tag %>\n"
# end

say 'Security hardening configured!', :green
say '   CSP headers disabled by default (review initializer to enable)', :cyan
say '   CORS configured for API routes', :cyan
say '   Run `bundle audit` to check for vulnerabilities', :yellow
