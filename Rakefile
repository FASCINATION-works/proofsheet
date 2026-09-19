# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Update USAGE.md with examples and generated images"
task :usage do
  require "proofsheet"
  require_relative "lib/proofsheet/usage_updater"
  Proofsheet::UsageUpdater.new.update!
end

task docs: :usage
