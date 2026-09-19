# frozen_string_literal: true

require "pathname"
require_relative "manifest"
require_relative "cli"

module Proofsheet
  class UsageUpdater
    MARKER_PATTERN = /(<!--\s*example:\s*(\S+)(?:[ \t]+([^\n>]+?))?\s*-->)(?:.*?)(<!--\s*end-example\s*-->)/m

    def initialize(doc_path: "USAGE.md", root: Dir.pwd, out: $stdout, **collaborators)
      @doc_path = doc_path
      @root = Pathname(root)
      @out = out
      @file_reader = collaborators.fetch(:file_reader, File.method(:read))
      @file_writer = collaborators.fetch(:file_writer, File.method(:write))
      @manifest_loader = collaborators.fetch(:manifest_loader, Manifest.method(:load))
      @cli_runner = collaborators.fetch(:cli_runner, method(:default_cli_runner))
    end

    def update!
      content = @file_reader.call(@root.join(@doc_path).to_s)
      configs = extract_configs(content)
      configs.each { |config| run_example(config) }

      updated = update_markdown(content)
      @file_writer.call(@root.join(@doc_path).to_s, updated)
      @out.puts "Updated #{@doc_path} with #{configs.size} examples."
    end

    def update_markdown(content)
      content.gsub(MARKER_PATTERN) do
        open_tag = Regexp.last_match(1)
        config_path = Regexp.last_match(2)
        attrs = Regexp.last_match(3)
        close_tag = Regexp.last_match(4)

        render_example(open_tag, config_path, attrs, close_tag)
      end
    end

    def extract_configs(content)
      content.scan(MARKER_PATTERN).map { |_, path, _| path }.uniq
    end

    private

    def render_example(open_tag, config_path, attrs, close_tag)
      yaml = @file_reader.call(@root.join(config_path).to_s).strip
      image_md = build_image_markdown(attrs)

      parts = [open_tag, "```yaml\n#{yaml}\n```"]
      parts << image_md unless image_md.empty?
      parts << close_tag
      parts.join("\n\n")
    end

    def build_image_markdown(attrs)
      return "" unless attrs

      if (images_match = attrs.match(/images:\s*([^\n]+)/))
        paths = images_match[1].split(",").map(&:strip)
        return paths.map { |path| "![#{File.basename(path, ".*")}](#{path})" }.join("\n\n")
      end

      image_match = attrs.match(/image:\s*(\S+)/)
      return "" unless image_match

      image_path = image_match[1]
      alt = parse_alt(attrs) || File.basename(image_path, ".*")
      "![#{alt}](#{image_path})"
    end

    def parse_alt(attrs)
      match = attrs.match(/alt:\s*"([^"]+)"/) || attrs.match(/alt:\s*(\S+)/)
      match[1] if match
    end

    def run_example(config_path)
      path = @root.join(config_path).to_s
      manifest = @manifest_loader.call(path)
      @out.puts "Running example: #{config_path}"
      @cli_runner.call(["capture", "--config", path])
      @cli_runner.call(["compose", "--config", path]) if manifest.composition_names.any?
    end

    def default_cli_runner(argv)
      ENV["AVO_DEMO_USERNAME"] ||= "avo@cado.com"
      ENV["AVO_DEMO_PASSWORD"] ||= "secreto"
      status = CLI.new(argv, out: @out, root: @root.to_s).run
      raise Error, "CLI failed for #{argv.join(" ")}" unless status.zero?
    end
  end
end
