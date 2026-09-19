# frozen_string_literal: true

module Proofsheet
  class CompositionConfig
    Background = Data.define(:color, :gradient, :image, :angle)
    Shadow = Data.define(:x, :y, :blur, :color)
    Crop = Data.define(:x, :y, :width, :height)
    Layer = Data.define(:shot, :image, :x, :y, :crop, :width, :radius, :rotate, :shadow)
    Composition = Data.define(:name, :width, :height, :background, :layers) do
      def filename
        "#{name}.png"
      end
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
      raise Error, unknown_message(name) if raw.nil?

      width, height = raw.fetch("canvas")
      Composition.new(name: name, width: width, height: height,
                      background: background(raw.fetch("background", "#ffffff")),
                      layers: raw.fetch("layers").map { |layer| layer_spec(layer, name) })
    rescue KeyError => e
      raise Error, "#{name}: #{e.message} in #{@path}"
    end

    private

    def unknown_message(name)
      "unknown composition #{name.inspect} — known compositions: #{names.join(", ")}"
    end

    def background(raw)
      return Background.new(color: raw, gradient: nil, image: nil, angle: 0) if raw.is_a?(String)

      Background.new(color: raw["color"], gradient: raw["gradient"], image: raw["image"],
                     angle: raw.fetch("angle", 0))
    end

    def layer_spec(raw, name)
      source = [raw["shot"], raw["image"]].compact
      raise Error, "#{name}: a layer must set exactly one of shot or image" unless source.one?

      Layer.new(shot: raw["shot"], image: raw["image"], x: raw.fetch("x", 0), y: raw.fetch("y", 0),
                crop: crop(raw["crop"]), width: raw["width"], radius: raw.fetch("radius", 0),
                rotate: raw.fetch("rotate", 0), shadow: shadow(raw["shadow"]))
    end

    def crop(raw)
      return if raw.nil?

      Crop.new(x: raw.fetch("x"), y: raw.fetch("y"),
               width: raw.fetch("width"), height: raw.fetch("height"))
    end

    def shadow(raw)
      return if raw.nil? || raw == false

      raw = {} if raw == true
      Shadow.new(x: raw.fetch("x", 0), y: raw.fetch("y", 16), blur: raw.fetch("blur", 24),
                 color: raw.fetch("color", "#00000055"))
    end
  end
end
