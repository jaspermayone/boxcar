# frozen_string_literal: true

say 'Writing CLAUDE.md...', :green

file 'CLAUDE.md', <<~MARKDOWN
  # CLAUDE.md

  This app was scaffolded with [boxcar](https://github.com/jaspermayone/boxcar), an opinionated Rails starter kit. This file documents the conventions, architecture, and key patterns in use.

  ---

  ## Stack

  - **Ruby on Rails** (Rails 8+)
  - **PostgreSQL** — multi-database setup (primary, queue, cache, cable)
  - **Redis** — caching, Action Cable, session store
  - **Tailwind CSS** — utility-first styling
  - **Bun** — JavaScript runtime/bundler
  - **GoodJob** — background jobs (Postgres-backed, no separate worker process needed in dev)

  ---

  ## Authentication

  This app uses **custom session-based authentication** (not Devise). Key files:

  - `app/models/user.rb` — `has_secure_password`, enum roles, email normalization
  - `app/models/session.rb` — tracks active sessions (token, IP, user agent)
  - `app/models/current.rb` — `Current.user` / `Current.session` via `CurrentAttributes`
  - `app/models/concerns/authentication.rb` — shared auth helpers
  - `app/controllers/sessions_controller.rb` — sign in / sign out
  - `app/controllers/registrations_controller.rb` — sign up

  ### User roles

  ```ruby
  enum :role, { user: 0, admin: 1, super_admin: 2, owner: 3 }, default: :user
  ```

  Helper methods on `User`:
  - `admin_or_above?` — true for admin, super_admin, owner
  - `super_admin_or_above?` — true for super_admin, owner

  ### Session cookies

  Sessions are stored as signed cookies (`session_token`). The `Authentication` concern provides `authenticate_user!` and `current_user` for controllers.

  ---

  ## Authorization

  **Pundit** is used for authorization. Policies live in `app/policies/`.

  - Call `authorize @resource` in controllers
  - Use `policy_scope(Model)` for scoped queries
  - `Admin::ApplicationController` enforces admin-or-above access for the entire admin namespace

  The `AdminConstraint` class (`app/constraints/admin_constraint.rb`) protects mounted engine routes at the router level using cookie-based session lookup.

  ---

  ## Public Identifiers

  Models use **encoded (hashid-based) public IDs** instead of exposing integer PKs. Include the concern and set a prefix:

  ```ruby
  include EncodedIds::HashidIdentifiable
  set_encoded_id_prefix :usr  # results in IDs like usr_abc123
  ```

  The salt lives in `rails credentials:edit` under `hashid.salt` (or `ENV["HASHID_SALT"]`).

  ---

  ## Database

  Four PostgreSQL databases are configured (see `config/database.yml`):

  | Database | Purpose | Migrations path |
  |----------|---------|----------------|
  | `#{app_name}_[env]` | Primary app data | `db/migrate/` |
  | `#{app_name}_queue_[env]` | GoodJob background jobs | `db/queue_migrate/` |
  | `#{app_name}_cache_[env]` | Solid Cache | `db/cache_migrate/` |
  | `#{app_name}_cable_[env]` | Action Cable | `db/cable_migrate/` |

  Run `rails db:create db:migrate` to set them all up.

  ---

  ## Background Jobs

  **GoodJob** handles background jobs using the primary PostgreSQL database — no separate Redis queue needed.

  - Define jobs in `app/jobs/`
  - GoodJob dashboard is mounted at `/admin/jobs` (admin+ only)
  - In development, GoodJob runs in-process (async mode)

  ---

  ## Feature Flags

  **Flipper** manages feature flags.

  ```ruby
  Flipper.enabled?(:my_feature)
  Flipper.enable(:my_feature)
  Flipper.enable_actor(:my_feature, current_user)
  ```

  The Flipper UI is mounted at `/admin/flipper` (super_admin+ only).

  ---

  ## Security

  ### Field-level encryption

  **Lockbox** + **BlindIndex** handle encrypted columns. Use the `Encryptable` concern:

  ```ruby
  include Encryptable
  encrypts_field :ssn
  encrypts_field :phone, searchable: true  # adds blind index for querying
  ```

  Add `_ciphertext` (and `_bidx` for searchable) columns in migrations. Keys live in credentials under `lockbox.master_key` and `blind_index.master_key`.

  ### Spam protection

  **InvisibleCaptcha** is available in forms. Add to a controller:

  ```ruby
  invisible_captcha only: [:create], on_spam: :spam_detected
  ```

  ### Safe migrations

  **StrongMigrations** is enabled — it will block unsafe operations (adding non-null columns without defaults, etc.) and suggest safer alternatives.

  ---

  ## Admin Section

  All admin routes live under `/admin` and require authentication via `AdminConstraint`.

  | Path | Tool | Min role |
  |------|------|----------|
  | `/admin/blazer` | Blazer SQL BI | admin |
  | `/admin/flipper` | Feature flags UI | super_admin |
  | `/admin/performance` | Rails Performance | admin |
  | `/admin/jobs` | GoodJob dashboard | admin |
  | `/admin/console_audits` | Console1984 audit log | super_admin |
  | `/admin/pghero` | PgHero DB dashboard | admin |
  | `/admin/users` | User management | admin |
  | `/health` | OkComputer health checks | public |

  ---

  ## Audit Logging

  **PaperTrail** tracks changes to records. Add to any model:

  ```ruby
  has_paper_trail
  ```

  Versions are stored in the `versions` table.

  ---

  ## Soft Delete

  **Paranoia** (or the configured soft-delete gem) is available. Add to models:

  ```ruby
  acts_as_paranoid
  ```

  Records get a `deleted_at` timestamp instead of being destroyed.

  ---

  ## Search

  **pg_search** provides full-text search via PostgreSQL:

  ```ruby
  include PgSearch::Model
  pg_search_scope :search, against: [:name, :email]
  ```

  ---

  ## SEO & Meta Tags

  **Meta-tags** gem handles page metadata. Set defaults in `ApplicationController` and override per action:

  ```ruby
  set_meta_tags title: 'Page Title', description: '...'
  ```

  A `sitemap.xml` and `robots.txt` are generated at `/sitemap.xml` and `/robots.txt`.

  ---

  ## Analytics

  **Ahoy** tracks visits and events:

  ```ruby
  ahoy.track 'Signed up', plan: 'pro'
  ```

  Visits and events are stored in the `ahoy_visits` and `ahoy_events` tables.

  ---

  ## Email

  Mailers live in `app/mailers/`. In development, **LetterOpener** intercepts outgoing mail and opens it in the browser instead of sending it.

  **Mailkick** handles unsubscribes — check `user.mailkick_unsubscribed?` before sending marketing email.

  ---

  ## Pagination

  **Kaminari** handles pagination:

  ```ruby
  @users = User.page(params[:page]).per(25)
  ```

  ---

  ## State Machines

  **AASM** is available for state machine patterns:

  ```ruby
  include AASM
  aasm column: :status do
    state :pending, initial: true
    state :active
    event :activate do
      transitions from: :pending, to: :active
    end
  end
  ```

  ---

  ## Friendly URLs

  **FriendlyId** provides slug-based URLs:

  ```ruby
  extend FriendlyId
  friendly_id :name, use: :slugged
  ```

  Use `Model.friendly.find(params[:id])` in controllers.

  ---

  ## Metrics

  **StatsD** metrics are sent to Datadog (or any StatsD-compatible backend). Configure `STATSD_HOST` and `STATSD_PORT` in the environment.

  ---

  ## Logging

  Structured JSON logging is configured for production. In development, standard Rails logs are used.

  ---

  ## Key Environment Variables

  | Variable | Purpose |
  |----------|---------|
  | `DATABASE_URL` | PostgreSQL connection string |
  | `REDIS_URL` | Redis connection |
  | `HEALTH_CHECK_USER` | Basic auth for `/health` |
  | `HEALTH_CHECK_PASSWORD` | Basic auth for `/health` |
  | `STATSD_HOST` | StatsD metrics host |
  | `STATSD_PORT` | StatsD metrics port |

  Secrets (encryption keys, etc.) live in Rails encrypted credentials — edit with `rails credentials:edit`.

  ---

  ## Development Workflow

  ```bash
  bin/dev           # Start all processes (web, CSS watcher, GoodJob)
  rails db:migrate  # Run pending migrations
  rails console     # Rails console (audited by Console1984)
  ```

  ### Creating new modules / features

  Follow existing conventions:
  - Models include relevant concerns (`EncodedIds::HashidIdentifiable`, `PgSearch::Model`, etc.)
  - Use Pundit policies for authorization — never inline role checks in controllers
  - Encrypted sensitive fields with `Encryptable` concern + Lockbox
  - Use GoodJob for anything async — no inline `Thread.new`
  - Check `Flipper.enabled?(:feature)` for anything behind a flag
MARKDOWN

say 'CLAUDE.md written!', :green
