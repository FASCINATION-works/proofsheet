# frozen_string_literal: true

require "fileutils"
require "pathname"
require "vips"

module Proofsheet
  class Composer
    def initialize(manifest:, root: Dir.pwd, out: $stdout)
      @manifest = manifest
      @root = Pathname(root)
      @out = out
    end

    def compose(names = @manifest.composition_names)
      names.each { |name| compose_one(@manifest.composition(name)) }
    end

    private

    def compose_one(composition)
      @out.puts composition.name
      image = background_image(composition)
      composition.layers.each { |layer| image = add_layer(image, layer) }
      write(composition, image)
    end

    def background_image(composition)
      spec = composition.background
      return solid(composition.width, composition.height, spec.color) if spec.color
      return gradient(composition.width, composition.height, spec.gradient, spec.angle) if spec.gradient
      return cover_image(spec.image, composition.width, composition.height) if spec.image

      raise Error, "#{composition.name}: background must set color, gradient, or image"
    end

    def add_layer(canvas, layer)
      image = layer_image(layer)
      canvas = add_shadow(canvas, image, layer) if layer.shadow
      canvas.composite2(image, :over, x: layer.x, y: layer.y)
    end

    def layer_image(layer)
      image = load_image(output_path("#{layer.shot}.png"))
      image = Cropper.call(image, layer.crop) if layer.crop
      image = image.resize(layer.width.to_f / image.width) if layer.width
      image = RoundedCorners.call(image, layer.radius)
      image = image.rotate(layer.rotate, background: [0, 0, 0, 0]) unless layer.rotate.zero?
      image
    end

    def add_shadow(canvas, image, layer)
      shadow = layer.shadow
      alpha, padding = shadow_mask(image, shadow.blur)
      overlay = shadow_overlay(alpha, shadow.color)
      canvas.composite2(overlay, :over, x: layer.x + shadow.x - padding,
                                        y: layer.y + shadow.y - padding)
    end

    def shadow_mask(image, blur)
      padding = (blur * 3).ceil
      alpha = image.extract_band(3).embed(padding, padding, image.width + (padding * 2),
                                          image.height + (padding * 2), extend: :black)
      alpha = alpha.gaussblur(blur) if blur.positive?
      [alpha, padding]
    end

    def shadow_overlay(alpha, value)
      color = parse_color(value)
      opacity = color.pop
      rgb = solid(alpha.width, alpha.height, color).extract_band(0, n: 3)
      rgb.bandjoin(alpha * (opacity / 255.0))
    end

    def solid(width, height, color)
      channels = color.is_a?(Array) ? color : parse_color(color)
      rgb = Vips::Image.black(width, height).new_from_image(channels.first(3)).copy(interpretation: :srgb)
      rgb.bandjoin(channels.fetch(3, 255))
    end

    def gradient(width, height, colors, angle)
      raise Error, "gradient must contain exactly two colors" unless colors&.size == 2

      from, to = colors.map { |color| parse_color(color) }
      amount = gradient_amount(width, height, angle)
      channels = from.zip(to).map { |start, finish| (amount * (finish - start)) + start }
      channels.shift.bandjoin(channels).cast(:uchar).copy(interpretation: :srgb)
    end

    def gradient_amount(width, height, degrees)
      coordinates = Vips::Image.xyz(width, height)
      radians = degrees * Math::PI / 180
      projection = (coordinates[0] * Math.cos(radians)) + (coordinates[1] * Math.sin(radians))
      minimum = projection.min
      maximum = projection.max
      return Vips::Image.black(width, height) if minimum == maximum

      (projection - minimum) / (maximum - minimum)
    end

    def cover_image(path, width, height)
      image = load_image(@root.join(path))
      scale = [width.to_f / image.width, height.to_f / image.height].max
      image = image.resize(scale)
      image.crop((image.width - width) / 2, (image.height - height) / 2, width, height)
    end

    def load_image(path)
      raise Error, "image not found: #{path}" unless path.exist?

      image = Vips::Image.new_from_file(path.to_s, access: :sequential)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb
      image.has_alpha? ? image : image.bandjoin(255)
    end

    def parse_color(value)
      match = /\A#([0-9a-f]{6})([0-9a-f]{2})?\z/i.match(value.to_s)
      raise Error, "invalid color #{value.inspect}; use #RRGGBB or #RRGGBBAA" unless match

      (match[1].scan(/../) + [match[2] || "ff"]).map { |channel| channel.to_i(16) }
    end

    def output_path(filename) = @root.join(@manifest.output_dir, filename)

    def write(composition, image)
      path = output_path(composition.filename)
      FileUtils.mkdir_p(path.dirname)
      image.write_to_file(path.to_s)
      @out.puts "  wrote #{path.relative_path_from(@root)}"
    end
  end
end
