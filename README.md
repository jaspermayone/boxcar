# boxcar

my opinionated rails template for my projects.

## usage

```zsh
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

