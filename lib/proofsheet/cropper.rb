# frozen_string_literal: true

module Proofsheet
  class Cropper
    def self.call(image, spec)
      new(image, spec).call
    end

    def initialize(image, spec)
      @image = image
      @spec = spec
    end

    def call
      raise Error, "crop #{@spec.to_h} exceeds source image #{@image.width}×#{@image.height}" unless valid?

      @image.crop(@spec.x, @spec.y, @spec.width, @spec.height)
    end

    private

    def valid?
      @spec.x >= 0 && @spec.y >= 0 && positive_dimensions? && within_bounds?
    end

    def positive_dimensions?
      @spec.width.positive? && @spec.height.positive?
    end

    def within_bounds?
      @spec.x + @spec.width <= @image.width && @spec.y + @spec.height <= @image.height
    end
  end
end
