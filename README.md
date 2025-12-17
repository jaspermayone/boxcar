# 🚃 boxcar

A production-ready, opinionated Rails 7+ application template with 33 integrated modules for authentication, authorization, monitoring, and more.

Inspired by [@nora](https://github.com/24c02)'s [thirdrail](https://github.com/24c02/thirdrail).

## Features

| Category | Modules |
|----------|---------|
| **Auth & Security** | Custom auth, Pundit, Lockbox encryption, rate limiting |
| **Admin Dashboards** | Blazer, Flipper, Rails Performance, GoodJob, PgHero |
| **Data Management** | Soft deletes, audit trails, friendly URLs, full-text search |
| **Observability** | Health checks, analytics, console auditing, StatsD metrics |
| **Infrastructure** | Redis, PostgreSQL multi-db, GoodJob, Tailwind CSS |

## Installation

```bash
brew tap jaspermayone/tap
brew install boxcar
```

## Quick Start

```bash
rails new myapp \
    --no-rc \
    --skip-kamal \
    --skip-jbuilder \
    --skip-test \
    --skip-system-test \
    --skip-action-mailbox \
    --skip-action-text \
    --skip-active-storage \
    --skip-sprockets \
    --skip-i18n \
    --skip-spring \
    --javascript=bun \
    --css=tailwind \
    -d postgresql \
    -m https://raw.githubusercontent.com/jaspermayone/boxcar/main/template.rb
```

After generation:

```bash
cd myapp
bin/setup
bin/dev
```

## What's Included

### Authentication & Authorization

- **Custom Authentication** — Cookie-based sessions with bcrypt, no Devise dependency
- **User Roles** — Four-tier system: `user`, `admin`, `super_admin`, `owner`
- **Pundit** — Policy-based authorization with sensible defaults
- **Rate Limiting** — Rack::Attack throttling for login attempts and suspicious requests

### Security

- **Lockbox** — Field-level encryption (`encrypts :ssn`)
- **BlindIndex** — Search encrypted fields without decryption
- **InvisibleCaptcha** — Honeypot spam protection
- **Strong Migrations** — Prevents dangerous migrations in production
- **CSP & CORS** — Content Security Policy and cross-origin headers
- **Security Scanning** — Bundler-audit and Brakeman in CI

### Admin Dashboards

All mounted under `/admin` with role-based access:

| Dashboard | Path | Access | Purpose |
|-----------|------|--------|---------|
| Blazer | `/admin/blazer` | admin+ | SQL-based analytics |
| Flipper | `/admin/flipper` | super_admin+ | Feature flags |
| Performance | `/admin/performance` | admin+ | Request monitoring |
| Jobs | `/admin/jobs` | admin+ | Solid Queue dashboard |
| PgHero | `/admin/pghero` | admin+ | PostgreSQL insights |
| Console Audits | `/admin/console_audits` | super_admin+ | Rails console access logs |

### Data Features

- **Public IDs** — Hashid-based IDs for URLs (`usr_abc123` instead of `1`)
- **Paper Trail** — Automatic audit logging for model changes
- **Soft Delete** — `acts_as_paranoid` with recovery support
- **Friendly ID** — SEO-friendly URL slugs with history
- **pg_search** — PostgreSQL full-text search with ranking

### Background Jobs

- **Solid Queue** — PostgreSQL-backed job processing with built-in dashboard
- **Recurring Jobs** — Cron-like scheduling support
- **Job Monitoring** — Track and debug failed jobs with full history

### Monitoring & Analytics

- **Health Checks** — `/health` endpoint with database, cache, and Redis checks
- **Ahoy Analytics** — Visit and event tracking with email integration
- **StatsD Metrics** — Request timing, custom gauges, Datadog-ready
- **Console1984** — Encrypted audit logs for Rails console access
- **Lograge** — Structured JSON logging with request ID tracing
- **Logstop** — Automatic PII filtering from logs

### Infrastructure

- **PostgreSQL** — Multi-database setup (primary, queue, cache, cable)
- **Redis** — Sessions (db 2), cache (db 1), rate limiting (db 5)
- **Tailwind CSS** — Pre-configured and ready to customize
- **IdentityCache** — Blob-level caching for ActiveRecord
- **PgHero** — PostgreSQL performance insights

### Email

- **Transactional Templates** — Welcome, password reset, email confirmation
- **Email Previews** — Preview emails in development
- **Premailer** — Automatic CSS inlining for email clients
- **Mailkick** — Unsubscribe management

## Included Concerns

Drop these into your models as needed:

```ruby
class User < ApplicationRecord
  include PublicIdentifiable  # adds public_id method
  include Auditable           # adds audit_trail method
  include SoftDeletable       # adds soft delete behavior
  include Sluggable           # adds friendly URLs
  include Searchable          # adds full-text search
  include Trackable           # adds analytics tracking
  include Encryptable         # adds encryption DSL
  include Featureable         # adds feature flag support
end
```

## Generators

```bash
# Add soft delete to a model
rails g soft_delete Post

# Add full-text search to a model
rails g search_index Post title:A content:B
```

## Configuration

### Required Credentials

Set these in `config/credentials.yml.enc`:

```yaml
hashid_salt: "your-random-salt-here"

lockbox:
  master_key: "generate-with-lockbox-gem"

blind_index:
  master_key: "generate-with-blind-index-gem"
```

### Environment Variables

```bash
# Health check authentication (production)
HEALTH_CHECK_USER=monitor
HEALTH_CHECK_PASSWORD=secret

# Redis
REDIS_URL=redis://localhost:6379

# StatsD (optional)
STATSD_HOST=localhost
STATSD_PORT=8125
```

## Routes Overview

```
/                     # Your app
/sign_in              # Authentication
/sign_up              # Registration
/health               # Health checks (public)
/health/all           # All health checks
/admin                # Admin namespace
/admin/users          # User management
/admin/blazer         # SQL analytics
/admin/flipper        # Feature flags
/admin/performance    # Request monitoring
/admin/jobs           # Background jobs
/admin/console_audits # Console access logs
```

## Development Tools

Automatically configured:

- **Bullet** — N+1 query detection
- **LetterOpener** — Email preview at `/letter_opener`
- **Query Count** — SQL query logging
- **Annotate** — Schema comments in models
- **Pry** — Enhanced Rails console

## Customization

### Adding a New Module

1. Create `your_module.rb` in the template root
2. Use the Rails template DSL:

```ruby
# your_module.rb
say "Installing YourModule...", :green

gem "some_gem"

after_bundle do
  generate "some_gem:install"

  initializer "your_module.rb", <<~RUBY
    # Configuration here
  RUBY
end

say "YourModule installed!", :green
```

3. Apply it in `template.rb`:

```ruby
apply "your_module.rb"
```

### Creating a New Module via Command

```bash
# Uses the /new-module slash command
/new-module notifications
```

## Architecture Decisions

- **No Devise** — Custom auth for full control and simplicity
- **No Sidekiq** — Solid Queue uses PostgreSQL, one less dependency
- **No Sprockets** — Modern asset pipeline with import maps or bundler
- **PostgreSQL Required** — Leverages pg_search, Row Level Security, advisory locks

## Requirements

- Ruby 3.2+
- Rails 7.1+
- PostgreSQL 14+
- Redis 7+
- Node.js 18+ / Bun

## License

MIT

## Acknowledgments

- Inspired by [@nora](https://github.com/24c02)'s [thirdrail](https://github.com/24c02/thirdrail)
- Built with gems from the amazing Ruby community
