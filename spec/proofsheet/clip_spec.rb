# frozen_string_literal: true

RSpec.describe Proofsheet::Clip do
  def rect(left:, top:, width:, height:)
    { "x" => left, "y" => top, "width" => width, "height" => height }
  end

  def clip(rect, full_width: false, padding: 0)
    described_class.from_rect(rect, image_width: 1440, image_height: 900,
                                    full_width: full_width, padding: padding)
  end

  it "rounds outward so no edge of the element is shaved off" do
    result = clip(rect(left: 10.6, top: 20.2, width: 100.1, height: 50.9))

    expect(result).to have_attributes(left: 10, top: 20, width: 101, height: 51)
  end

  it "widens to the full image when asked" do
    result = clip(rect(left: 120, top: 40, width: 800, height: 143), full_width: true)

    expect(result).to have_attributes(left: 0, top: 40, width: 1440, height: 143)
  end

  it "clamps a padded element to the image" do
    result = clip(rect(left: 0, top: 880, width: 100, height: 30), padding: 5)

    expect(result).to have_attributes(left: 0, top: 875, width: 110, height: 25)
  end
end
