---
description: Create a new boxcar module/template
argument-hint: <module-name>
---

Create a new boxcar module called `$ARGUMENTS.rb` in this Rails template project.

## Context
- This is a Rails application template project (used with `rails new myapp -m template.rb`)
- Modules are Ruby files that get applied via `apply_template('$ARGUMENTS')` in `template.rb`
- Each module should be self-contained and handle one feature/concern

## Module Structure
Follow the existing patterns in this project. A module should:

1. Start with `# frozen_string_literal: true`
2. Use `say` with colors for user feedback:
   - `:green` for main section headers
   - `:cyan` for sub-steps
   - `:yellow` for warnings
   - `:red` for errors
3. Use Rails template methods like:
   - `gem 'name'` - add gems
   - `generate :model, 'Name field:type'` - run generators
   - `file 'path', <<~RUBY ... RUBY` - create files
   - `inject_into_file`, `gsub_file` - modify files
   - `route` - add routes
   - `after_bundle do ... end` - run code after bundle install

## Reference Files
Look at these existing modules for patterns:
- @auth.rb - authentication module
- @public_identifiable.rb - public IDs module
- @tailwind.rb - Tailwind CSS module
- @template.rb - main template entry point

## Task
1. Ask what the module should do if not clear from the name
2. Create the module file `$ARGUMENTS.rb`
3. Show how to add it to `template.rb` using `apply_template('$ARGUMENTS')`
