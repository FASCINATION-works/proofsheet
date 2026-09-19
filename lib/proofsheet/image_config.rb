# frozen_string_literal: true

module Proofsheet
  class ImageConfig
    SOURCES = %w[path url page].freeze

    Image = Data.define(:name, :path, :url, :page, :selector) do
      def filename = "#{name}.png"
      def local? = !path.nil?
    end

    def initialize(data, path:)
      @data = data
      @path = path
    end

    def names
      @data.keys
    end

    def fetch(name)
      raw = @data[name]
      raise Error, "unknown image #{name.inspect} — known images: #{names.join(", ")}" if raw.nil?

      sources = SOURCES.select { |key| raw[key] }
      raise Error, "#{name}: set exactly one of path, url, or page in #{@path}" unless sources.one?

      validate_selector(name, raw)

      Image.new(name: name, path: raw["path"], url: raw["url"], page: raw["page"],
                selector: raw["selector"])
    end

    private

    def validate_selector(name, raw)
      raise Error, "#{name}: page requires selector in #{@path}" if raw["page"] && !raw["selector"]
      return unless raw["selector"] && !raw["page"]

      raise Error, "#{name}: selector can only be used with page in #{@path}"
    end
  end
end
