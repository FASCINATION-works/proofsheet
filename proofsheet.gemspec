# frozen_string_literal: true

require_relative "lib/proofsheet/version"

Gem::Specification.new do |spec|
  spec.name = "proofsheet"
  spec.version = Proofsheet::VERSION
  spec.authors = ["Marc Heiligers"]
  spec.email = ["marc@eternal.co.za"]

  spec.summary = "Capture repeatable screenshots from web applications"
  spec.description = "Automate screenshots from web apps for your documentation, landings pages and emails"
  spec.homepage = "https://github.com/FASCINATION-works/proofsheet"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f == "lib/proofsheet/usage_updater.rb" ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "capybara", "~> 3.40"
  spec.add_dependency "ruby-vips", "~> 2.3"
  spec.add_dependency "selenium-webdriver", "~> 4.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
