# frozen_string_literal: true

say 'Setting up AASM for state machines...', :green

gem 'aasm'

say 'AASM configured!', :green
say '   Usage:', :cyan
say '     include AASM in your model', :cyan
say '     Define states and events with aasm block', :cyan
say '   Migration: add_column :table, :state, :string, default: "initial"', :cyan
