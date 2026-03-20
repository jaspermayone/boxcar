# frozen_string_literal: true

say '🚃 boxcar - Rails starter kit', :cyan
say ''

# ═══════════════════════════════════════════════════════════════════════════════
# Template Configuration
# ═══════════════════════════════════════════════════════════════════════════════

TEMPLATE_ROOT = if __FILE__.start_with?('http')
                  File.dirname(__FILE__)
                else
                  __dir__
                end

@post_install_tasks = []

def apply_module(name, tasks = [])
  apply File.join(TEMPLATE_ROOT, 'modules', "#{name}.rb")
  @post_install_tasks.concat(tasks)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Remove Rails 8 defaults we'll replace
# ═══════════════════════════════════════════════════════════════════════════════

remove_file 'config/initializers/content_security_policy.rb'

# ═══════════════════════════════════════════════════════════════════════════════
# Base Setup
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('base_gems')
apply_module('credentials')
apply_module('development_tools')
apply_module('github')
apply_module('logging')

# ═══════════════════════════════════════════════════════════════════════════════
# Database & Infrastructure
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('database')
apply_module('redis')
apply_module('caching')

# ═══════════════════════════════════════════════════════════════════════════════
# Security
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('security')

# ═══════════════════════════════════════════════════════════════════════════════
# Authentication & Authorization
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('public_identifiable')
apply_module('auth', ['run `rails db:migrate`'])
apply_module('pundit')

# ═══════════════════════════════════════════════════════════════════════════════
# Frontend & SEO
# ═══════════════════════════════════════════════════════════════════════════════

gem 'tailwindcss-rails'
apply_module('tailwind')
apply_module('seo')

# ═══════════════════════════════════════════════════════════════════════════════
# Background Jobs & Feature Flags
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('good_job')
apply_module('flipper')

# ═══════════════════════════════════════════════════════════════════════════════
# Admin Dashboards
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('blazer')
apply_module('rails_performance')
apply_module('console1984')
apply_module('pghero')

# ═══════════════════════════════════════════════════════════════════════════════
# Monitoring & Analytics
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('health_checks')
apply_module('analytics')
apply_module('metrics')

# ═══════════════════════════════════════════════════════════════════════════════
# Data Management
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('paper_trail')
apply_module('soft_delete')
apply_module('friendly_id')
apply_module('pg_search')
apply_module('aasm')

# ═══════════════════════════════════════════════════════════════════════════════
# Email & Pagination
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('kaminari')
apply_module('mailkick')
apply_module('email')

# ═══════════════════════════════════════════════════════════════════════════════
# Admin Routes (must be last - depends on all admin modules)
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('admin_routes')

# ═══════════════════════════════════════════════════════════════════════════════
# Documentation
# ═══════════════════════════════════════════════════════════════════════════════

apply_module('claude_md')

# ═══════════════════════════════════════════════════════════════════════════════
# Initial commit
# ═══════════════════════════════════════════════════════════════════════════════

after_bundle do
  say '   Creating initial commit...', :cyan
  git add: '.'
  git commit: '-m "init from boxcar"'
end

# ═══════════════════════════════════════════════════════════════════════════════
# Finish
# ═══════════════════════════════════════════════════════════════════════════════

say ''
say ''
say '✅ boxcar setup complete!', :green
say ''

if @post_install_tasks.any?
  say 'Next steps:', :yellow
  @post_install_tasks.uniq.each { |task| say "  - #{task}", :yellow }
  say ''
end

say 'Run `cd #{app_name} && bin/dev` to start your app', :cyan
say ''
