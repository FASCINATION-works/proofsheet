# frozen_string_literal: true

require "yaml"

module Proofsheet
  class Manifest
    ClipSpec = Data.define(:selector, :full_width, :padding)
    Expectation = Data.define(:selector, :text)
    Login = Data.define(:path, :username_field, :password_field, :submit, :expectation)

    Shot = Data.define(:name, :path_template, :wait_for, :click, :clip, :expectation,
                       :path_script, :resolved_wait_for) do
      def clip?
        !clip.nil?
      end

      def filename
        "#{name}.png"
      end
    end

    DEFAULT_PATH = "proofsheet.yml"

    def self.load(path = DEFAULT_PATH)
      new(YAML.safe_load_file(path), path: path)
    rescue Errno::ENOENT
      raise Error, "manifest not found: #{path}"
    rescue Psych::Exception => e
      raise Error, "could not read #{path}: #{e.message}"
    end

    attr_reader :path

    def initialize(data, path: DEFAULT_PATH)
      @data = data
      @path = path
    end

    def host
      @data["host"]
    end

    def expected_username
      @data.dig("expect", "username")
    end

    def viewport
      defaults.fetch("viewport", [1440, 900])
    end

    def output_dir
      defaults.fetch("output_dir", "screenshots")
    end

    def credentials
      @data.fetch("credentials")
    end

    def login
      raw = @data["login"]
      return if raw.nil?

      Login.new(path: raw.fetch("path"), username_field: raw.fetch("username_field"),
                password_field: raw.fetch("password_field"), submit: raw.fetch("submit"),
                expectation: expectation(raw["expect"]))
    end

    def names
      shot_data.keys
    end

    def shots
      names.map { |name| shot(name) }
    end

    def image_names = image_config.names

    def image(name) = image_config.fetch(name)

    def layer_path(layer)
      return File.join(output_dir, "#{layer.shot}.png") if layer.shot

      source = image(layer.image)
      source.local? ? source.path : File.join(output_dir, source.filename)
    end

    def composition_names = composition_config.names

    def composition(name)
      composition_config.fetch(name)
    end

    def shot(name)
      raw = shot_data[name]
      raise Error, "unknown shot #{name.inspect} — known shots: #{names.join(", ")}" if raw.nil?

      Shot.new(name: name, path_template: raw.fetch("path"), wait_for: raw["wait_for"],
               click: raw["click"], clip: clip_spec(raw["clip"]), expectation: expectation(raw["expect"]),
               path_script: raw["path_script"], resolved_wait_for: raw["resolved_wait_for"])
    rescue KeyError => e
      raise Error, "#{name}: #{e.message} in #{@path}"
    end

    def path_for(shot)
      shot.path_template.gsub(/%\{(\w+)\}/) do
        key = Regexp.last_match(1)
        raise Error, "#{shot.name}: no target named #{key.inspect} in #{@path}" unless targets.key?(key)

        value = targets[key]
        raise Error, "#{shot.name}: targets.#{key} is not set in #{@path}" if value.nil? || value.empty?

        value
      end
    end

    private

    def defaults
      @data.fetch("defaults", {})
    end

    def clip_spec(raw)
      return if raw.nil?

      ClipSpec.new(selector: raw.fetch("selector"), full_width: raw.fetch("full_width", false),
                   padding: raw.fetch("padding", 0))
    end

    def expectation(raw)
      return if raw.nil?

      Expectation.new(selector: raw.fetch("selector"), text: raw.fetch("text"))
    end

    def targets
      @targets ||= @data.fetch("targets", {}).transform_values { |value| value&.to_s }
    end

    def shot_data
      @data.fetch("shots")
    rescue KeyError
      raise Error, "shots is missing from #{@path}"
    end

    def image_config
      @image_config ||= ImageConfig.new(@data.fetch("images", {}), path: @path).tap do |config|
        reject_clashes(config.names)
      end
    end

    def reject_clashes(names)
      clashes = names & shot_data.keys
      return if clashes.empty?

      raise Error, "#{clashes.join(", ")} named as both a shot and an image in #{@path}"
    end

    def composition_config
      @composition_config ||= CompositionConfig.new(@data.fetch("compositions", {}), path: @path)
    end
  end
end
