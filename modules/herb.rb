# frozen_string_literal: true

say 'Setting up herb (HTML-aware ERB tooling)...', :green

gem_group :development do
  gem 'herb'
end

file '.herb.yml', <<~YAML
  linter:
    enabled: true
    failLevel: error
    exclude:
      - 'node_modules/**'
    rules:
      html-tag-name-lowercase:
        severity: error
      html-attribute-double-quotes:
        severity: error
      html-img-require-alt:
        severity: error
      erb-require-trailing-newline:
        severity: error
      erb-prefer-direct-output:
        severity: warning

  formatter:
    enabled: true
    indentWidth: 2
    maxLineLength: 120
YAML

file '.github/workflows/herb.yml', <<~YAML
  name: Herb

  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]
      paths:
        - 'app/views/**/*.html.erb'
        - 'app/views/**/*.turbo_stream.erb'
        - '.herb.yml'

  jobs:
    lint:
      name: Lint ERB
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - name: Lint with herb
          run: npx --yes @herb-tools/linter

    format:
      name: Format check ERB
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - name: Check formatting with herb
          run: npx --yes @herb-tools/formatter --check
YAML

say 'herb configured!', :green
