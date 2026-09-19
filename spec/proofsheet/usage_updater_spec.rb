# frozen_string_literal: true

require "proofsheet/usage_updater"

RSpec.describe Proofsheet::UsageUpdater do
  let(:doc_content) do
    <<~MD
      # Usage Guide

      Here is a simple example:

      <!-- example: examples/01_simple.yml image: examples/output/homepage.png alt: "Example Domain" -->
      old yaml
      old image
      <!-- end-example -->

      Here is an image fetch:

      <!-- example: examples/04_fetching.yml images: examples/output/cat.png, examples/output/logo.png -->
      <!-- end-example -->
    MD
  end

  let(:simple_yaml) do
    <<~YAML
      host: "https://example.com"
      shots:
        homepage:
          path: "/"
    YAML
  end

  let(:fetching_yaml) do
    <<~YAML
      host: "https://example.com"
      shots:
        dummy:
          path: "/"
      images:
        cat:
          url: "https://placecats.com/300/200"
    YAML
  end

  let(:files) do
    {
      "/project/USAGE.md" => doc_content,
      "/project/examples/01_simple.yml" => simple_yaml,
      "/project/examples/04_fetching.yml" => fetching_yaml
    }
  end

  let(:file_reader) { ->(path) { files.fetch(path) } }
  let(:written) { {} }
  let(:file_writer) { ->(path, content) { written[path] = content } }
  let(:cli_calls) { [] }
  let(:cli_runner) { ->(argv) { cli_calls << argv } }
  let(:manifest_loader) do
    lambda do |path|
      data = YAML.safe_load(files.fetch(path))
      Proofsheet::Manifest.new(data, path: path)
    end
  end

  subject(:updater) do
    described_class.new(
      doc_path: "USAGE.md",
      root: "/project",
      out: StringIO.new,
      file_reader: file_reader,
      file_writer: file_writer,
      manifest_loader: manifest_loader,
      cli_runner: cli_runner
    )
  end

  it "extracts example config paths from markdown markers" do
    expect(updater.extract_configs(doc_content)).to eq(["examples/01_simple.yml", "examples/04_fetching.yml"])
  end

  it "updates the markdown content with YAML blocks and image links" do
    updated = updater.update_markdown(doc_content)
    expected_tag = '<!-- example: examples/01_simple.yml image: examples/output/homepage.png alt: "Example Domain" -->'

    expect(updated).to include(expected_tag)
    expect(updated).to include("```yaml\n#{simple_yaml.strip}\n```")
    expect(updated).to include("![Example Domain](examples/output/homepage.png)")
    expect(updated).to include("![cat](examples/output/cat.png)\n\n![logo](examples/output/logo.png)")
    expect(updated).to include("# Usage Guide")
  end

  it "runs capture for each referenced example configuration" do
    updater.update!

    expect(cli_calls).to eq(
      [
        ["capture", "--config", "/project/examples/01_simple.yml"],
        ["capture", "--config", "/project/examples/04_fetching.yml"]
      ]
    )
    expect(written["/project/USAGE.md"]).to be_a(String)
  end

  it "runs compose when an example defines compositions" do
    composition_yaml = <<~YAML
      host: "https://example.com"
      shots:
        card:
          path: "/"
      compositions:
        hero:
          canvas: [1200, 800]
          layers:
            - shot: card
    YAML
    doc_with_composition = <<~MD
      <!-- example: examples/05_comp.yml image: examples/output/hero.png -->
      <!-- end-example -->
    MD
    files["/project/USAGE.md"] = doc_with_composition
    files["/project/examples/05_comp.yml"] = composition_yaml

    updater.update!

    expect(cli_calls).to eq(
      [
        ["capture", "--config", "/project/examples/05_comp.yml"],
        ["compose", "--config", "/project/examples/05_comp.yml"]
      ]
    )
  end
end
