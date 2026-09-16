# frozen_string_literal: true

module Proofsheet
  Clip = Data.define(:left, :top, :width, :height) do
    def self.from_rect(rect, image_width:, image_height:, full_width: false, padding: 0)
      left, width = full_width ? [0, image_width] : axis(rect["x"], rect["width"], image_width, padding)
      top, height = axis(rect["y"], rect["height"], image_height, padding)

      new(left: left, top: top, width: width, height: height)
    end

    def self.axis(offset, length, limit, padding)
      start = (offset.floor - padding).clamp(0, limit - 1)

      [start, (length.ceil + (padding * 2)).clamp(1, limit - start)]
    end

    def to_s
      "#{width}×#{height} at #{left},#{top}"
    end
  end
end
