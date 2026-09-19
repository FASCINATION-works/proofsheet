# frozen_string_literal: true

RSpec.describe Proofsheet do
  it "has a version number" do
    expect(Proofsheet::VERSION).not_to be_nil
  end

  it "does not package the documentation updater" do
    gemspec = Gem::Specification.load(File.expand_path("../proofsheet.gemspec", __dir__))

    expect(gemspec.files).not_to include("lib/proofsheet/usage_updater.rb")
  end
end
