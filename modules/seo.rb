# frozen_string_literal: true

say 'Setting up SEO & navigation helpers...', :green

gem 'meta-tags'
gem 'active_link_to'

say '   Configuring meta-tags...', :cyan
initializer 'meta_tags.rb', <<~RUBY
  # frozen_string_literal: true

  MetaTags.configure do |config|
    # How many characters to truncate title to
    config.title_limit = 70

    # How many characters to truncate description to
    config.description_limit = 160

    # Truncate site_title if title is too long
    config.truncate_site_title_first = false
  end
RUBY

say '   Adding meta tags to layout...', :cyan
inject_into_file 'app/views/layouts/application.html.erb', after: "<%= csp_meta_tag %>\n" do
  "    <%= display_meta_tags site: '#{app_name.titleize}' %>\n"
end

say '   Creating SEO helper...', :cyan
file 'app/helpers/seo_helper.rb', <<~RUBY
  # frozen_string_literal: true

  # Usage in controllers or views:
  #   set_meta_tags title: 'Page Title',
  #                 description: 'Page description',
  #                 keywords: 'keyword1, keyword2'
  #
  # Or use the helpers:
  #   page_title 'My Page'
  #   page_description 'Description here'
  #
  module SeoHelper
    def page_title(title)
      set_meta_tags title: title
    end

    def page_description(description)
      set_meta_tags description: description
    end

    def page_image(image_url)
      set_meta_tags og: { image: image_url },
                    twitter: { image: image_url }
    end

    # Full SEO setup for a page
    def page_seo(title:, description: nil, image: nil, type: 'website')
      tags = {
        title: title,
        og: { title: title, type: type },
        twitter: { card: 'summary_large_image', title: title }
      }

      if description
        tags[:description] = description
        tags[:og][:description] = description
        tags[:twitter][:description] = description
      end

      if image
        tags[:og][:image] = image
        tags[:twitter][:image] = image
      end

      set_meta_tags tags
    end
  end
RUBY

say '   Creating navigation helper...', :cyan
file 'app/helpers/navigation_helper.rb', <<~RUBY
  # frozen_string_literal: true

  # Navigation helpers using active_link_to
  #
  # Usage:
  #   <%= nav_link_to 'Home', root_path %>
  #   <%= nav_link_to 'Users', users_path, class: 'nav-item' %>
  #
  # The link gets an 'active' class when on that page.
  # Customize with active_link_to options:
  #   active: :exact         # Only exact URL match
  #   active: :inclusive     # Match URL and sub-paths (default)
  #   active: /regex/        # Match against regex
  #   active: ['path1', 'path2']  # Match multiple paths
  #
  module NavigationHelper
    def nav_link_to(name, path, options = {})
      default_options = {
        class: 'nav-link',
        active_class: 'active'
      }
      active_link_to(name, path, default_options.merge(options))
    end

    # For nav items with icons
    def nav_link_with_icon(name, icon_class, path, options = {})
      content = tag.i(class: icon_class) + ' ' + name
      nav_link_to(content, path, options)
    end
  end
RUBY

say 'SEO & navigation configured!', :green
say '   Use `page_seo title: "..."` in controllers', :cyan
say '   Use `nav_link_to` for auto-highlighting nav links', :cyan
