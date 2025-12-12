# frozen_string_literal: true

say 'Setting up credentials...', :green

# Initialize credentials for each environment (after bundle)
after_bundle do
  say '   Creating environment credentials...', :cyan
  %w[development staging production].each do |env|
    say "      #{env}...", :cyan
    run "EDITOR='echo' bin/rails credentials:edit --environment #{env}", abort_on_failure: false
  end
end

# Create credentials example file
file 'config/credentials.yml.example', <<~YAML
  # Credentials structure for all environments
  # Edit with: EDITOR=nano rails credentials:edit --environment <env>
  #
  # Generate keys in rails console:
  #   Lockbox.generate_key
  #   BlindIndex.generate_key
  #   SecureRandom.hex(32)

  secret_key_base: # auto-generated

  lockbox:
    master_key: # Lockbox.generate_key

  blind_index:
    master_key: # BlindIndex.generate_key

  hashid:
    salt: # SecureRandom.hex(32)
YAML

say 'Credentials configured!', :green
