# frozen_string_literal: true

require "tmpdir"
require "vips"

RSpec.describe Proofsheet::Composer do
  def manifest(compositions, images = {})
    Proofsheet::Manifest.new({
                               "defaults" => { "output_dir" => "screenshots" },
                               "shots" => {},
                               "images" => images,
                               "compositions" => compositions
                             })
  end

  def write_image(path, width, height, color)
    image = Vips::Image.black(width, height).new_from_image(color).copy(interpretation: :srgb)
    image.write_to_file(path)
  end

  it "places and resizes screenshots on a solid canvas" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "screenshots"))
      write_image(File.join(dir, "screenshots/card.png"), 20, 10, [255, 0, 0])
      subject = manifest("hero" => {
                           "canvas" => [100, 80], "background" => "#112233",
                           "layers" => [{
                             "shot" => "card", "x" => 10, "y" => 20,
                             "crop" => { "x" => 5, "y" => 2, "width" => 10, "height" => 4 }, "width" => 40
                           }]
                         })

      described_class.new(manifest: subject, root: dir, out: StringIO.new).compose
      result = Vips::Image.new_from_file(File.join(dir, "screenshots/hero.png"))

      expect([result.width, result.height]).to eq([100, 80])
      expect(result.getpoint(0, 0).first(3)).to eq([17.0, 34.0, 51.0])
      expect(result.getpoint(10, 20).first(3)).to eq([255.0, 0.0, 0.0])
      expect(result.getpoint(49, 35).first(3)).to eq([255.0, 0.0, 0.0])
      expect(result.getpoint(10, 36).first(3)).to eq([17.0, 34.0, 51.0])
    end
  end

  it "rejects crops outside the source screenshot" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "screenshots"))
      write_image(File.join(dir, "screenshots/card.png"), 20, 10, [255, 0, 0])
      subject = manifest("hero" => {
                           "canvas" => [100, 80],
                           "layers" => [{
                             "shot" => "card",
                             "crop" => { "x" => 10, "y" => 0, "width" => 20, "height" => 10 }
                           }]
                         })

      expect { described_class.new(manifest: subject, root: dir, out: StringIO.new).compose }
        .to raise_error(Proofsheet::Error, /exceeds source image 20×10/)
    end
  end

  it "rounds screenshot layer corners" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "screenshots"))
      write_image(File.join(dir, "screenshots/card.png"), 20, 10, [255, 0, 0])
      subject = manifest("hero" => {
                           "canvas" => [40, 30], "background" => "#112233",
                           "layers" => [{ "shot" => "card", "x" => 10, "y" => 10, "radius" => 4 }]
                         })

      described_class.new(manifest: subject, root: dir, out: StringIO.new).compose
      result = Vips::Image.new_from_file(File.join(dir, "screenshots/hero.png"))

      expect(result.getpoint(10, 10).first(3)).to eq([17.0, 34.0, 51.0])
      expect(result.getpoint(10, 15).first(3)).to eq([255.0, 0.0, 0.0])
      expect(result.getpoint(20, 15).first(3)).to eq([255.0, 0.0, 0.0])
    end
  end

  it "supports gradient backgrounds, rotation, and shadows" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "screenshots"))
      write_image(File.join(dir, "screenshots/card.png"), 20, 10, [255, 255, 255])
      subject = manifest("hero" => {
                           "canvas" => [100, 80],
                           "background" => { "gradient" => ["#ff0000", "#0000ff"], "angle" => 45 },
                           "layers" => [{ "shot" => "card", "x" => 30, "y" => 25, "rotate" => -5,
                                          "shadow" => true }]
                         })

      described_class.new(manifest: subject, root: dir, out: StringIO.new).compose
      result = Vips::Image.new_from_file(File.join(dir, "screenshots/hero.png"))

      expect([result.width, result.height]).to eq([100, 80])
      expect(result.getpoint(0, 0).first(3)).not_to eq(result.getpoint(99, 79).first(3))
    end
  end

  it "draws an image layer read from a path below the project root" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "assets"))
      write_image(File.join(dir, "assets/logo.png"), 10, 10, [0, 0, 255])
      subject = manifest({ "hero" => { "canvas" => [40, 40], "background" => "#112233",
                                       "layers" => [{ "image" => "logo", "x" => 5, "y" => 5 }] } },
                         "logo" => { "path" => "assets/logo.png" })

      described_class.new(manifest: subject, root: dir, out: StringIO.new).compose
      result = Vips::Image.new_from_file(File.join(dir, "screenshots/hero.png"))

      expect(result.getpoint(5, 5).first(3)).to eq([0.0, 0.0, 255.0])
      expect(result.getpoint(15, 15).first(3)).to eq([17.0, 34.0, 51.0])
    end
  end

  it "draws a fetched image layer from the output directory, where capture left it" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "screenshots"))
      write_image(File.join(dir, "screenshots/partner.png"), 10, 10, [0, 255, 0])
      subject = manifest({ "hero" => { "canvas" => [40, 40], "background" => "#112233",
                                       "layers" => [{ "image" => "partner", "x" => 5, "y" => 5 }] } },
                         "partner" => { "url" => "https://cdn.example.test/partner.png" })

      described_class.new(manifest: subject, root: dir, out: StringIO.new).compose
      result = Vips::Image.new_from_file(File.join(dir, "screenshots/hero.png"))

      expect(result.getpoint(5, 5).first(3)).to eq([0.0, 255.0, 0.0])
    end
  end

  it "covers the canvas with a background image" do
    Dir.mktmpdir do |dir|
      write_image(File.join(dir, "background.png"), 10, 20, [0, 255, 0])
      subject = manifest("hero" => {
                           "canvas" => [40, 20], "background" => { "image" => "background.png" }, "layers" => []
                         })

      described_class.new(manifest: subject, root: dir, out: StringIO.new).compose
      result = Vips::Image.new_from_file(File.join(dir, "screenshots/hero.png"))

      expect([result.width, result.height]).to eq([40, 20])
      expect(result.getpoint(0, 0).first(3)).to eq([0.0, 255.0, 0.0])
    end
  end
end
