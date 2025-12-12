# frozen_string_literal: true

say 'Setting up GitHub workflows...', :green

empty_directory '.github/workflows'

say '   Adding migration index checker...', :cyan
file '.github/workflows/check-indexes.yml', <<~YAML
  name: Check Indexes
  on:
    pull_request:
      paths:
        - 'db/migrate/**.rb'

  jobs:
    check-indexes:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
          with:
            fetch-depth: 0

        - name: Check Migration Indexes
          uses: speedshop/ids_must_be_indexed@v1.2.1
YAML

say '   Adding security scanning...', :cyan
file '.github/workflows/security.yml', <<~YAML
  name: Security

  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]
    schedule:
      - cron: '0 6 * * 1' # Weekly on Monday at 6am

  jobs:
    bundler-audit:
      name: Bundler Audit
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Run bundler-audit
          run: |
            gem install bundler-audit
            bundle audit check --update

    brakeman:
      name: Brakeman
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Run Brakeman
          run: |
            gem install brakeman
            brakeman -q --no-pager
YAML

say 'GitHub workflows configured!', :green
