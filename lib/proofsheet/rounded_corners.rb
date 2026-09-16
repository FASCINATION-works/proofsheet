# frozen_string_literal: true

module Proofsheet
  class RoundedCorners
    def self.call(image, requested_radius)
      return image unless requested_radius.positive?

      new(image, requested_radius).call
    end

    def initialize(image, requested_radius)
      @image = image
      @radius = [requested_radius.to_f, image.width / 2.0, image.height / 2.0].min
    end

    def call
      alpha = (@image.extract_band(3) * (coverage / 255.0)).cast(:uchar)
      @image.extract_band(0, n: 3).bandjoin(alpha)
    end

    private

    def coverage
      distance = ((x_distance * x_distance) + (y_distance * y_distance))**0.5
      value = (((distance * -1) + @radius + 0.5) * 255)
      value = value.relational_const(:more, [255]).ifthenelse(255, value)
      value.relational_const(:less, [0]).ifthenelse(0, value)
    end

    def x_distance
      corner_distance(coordinates[0], @image.width)
    end

    def y_distance
      corner_distance(coordinates[1], @image.height)
    end

    def corner_distance(coordinate, length)
      distance = (coordinate - ((length - 1) / 2.0)).abs - ((length / 2.0) - @radius)
      distance.relational_const(:more, [0]).ifthenelse(distance, 0)
    end

    def coordinates
      @coordinates ||= Vips::Image.xyz(@image.width, @image.height)
    end
  end
end
