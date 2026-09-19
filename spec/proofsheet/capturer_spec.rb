# frozen_string_literal: true

require "tmpdir"

RSpec.describe Proofsheet::Capturer do
  let(:browser) { instance_double(Proofsheet::Browser) }
  let(:browser_class) { class_double(Proofsheet::Browser, new: browser) }

  def manifest(data = {})
    Proofsheet::Manifest.new({
      "host" => "https://example.test",
      "defaults" => { "viewport" => [1440, 900], "output_dir" => "shots" },
      "shots" => { "home" => { "path" => "/home" } }
    }.merge(data))
  end

  before do
    allow(browser).to receive_messages(start: browser, visit: nil, screenshot_png: "PNG", quit: nil)
  end

  it "captures named shots and writes them below the project root" do
    Dir.mktmpdir do |dir|
      described_class.new(manifest: manifest, host: "https://example.test", root: dir,
                          browser_class: browser_class, out: StringIO.new).capture(["home"])

      expect(File.binread(File.join(dir, "shots/home.png"))).to eq("PNG")
    end
  end

  it "crops a shot to its configured element" do
    require "vips"
    subject = manifest("shots" => { "chart" => {
                         "path" => "/dashboard", "clip" => { "selector" => ".chart", "padding" => 5 }
                       } })
    png = Vips::Image.black(1440, 900).write_to_buffer(".png")
    allow(browser).to receive_messages(
      rect_for: { "x" => 100, "y" => 200, "width" => 300, "height" => 400 },
      screenshot_png: png
    )

    Dir.mktmpdir do |dir|
      described_class.new(manifest: subject, host: "https://example.test", root: dir,
                          browser_class: browser_class, out: StringIO.new).capture
      image = Vips::Image.new_from_file(File.join(dir, "shots/chart.png"))

      expect([image.width, image.height]).to eq([310, 410])
    end
  end

  it "resolves a path with manifest JavaScript before capturing" do
    subject = manifest("shots" => { "report" => {
                         "path" => "/reports", "path_script" => "document.querySelector('a').pathname",
                         "resolved_wait_for" => "iframe"
                       } })
    allow(browser).to receive(:evaluate).and_return("/reports/42")

    expect(browser).to receive(:visit).with("/reports", wait_for: nil).ordered
    expect(browser).to receive(:visit).with("/reports/42", wait_for: "iframe").ordered

    Dir.mktmpdir do |dir|
      described_class.new(manifest: subject, host: "https://example.test", root: dir,
                          browser_class: browser_class, out: StringIO.new).capture
    end
  end

  it "downloads a url image as PNG without starting the browser" do
    subject = manifest("shots" => {},
                       "images" => { "partner" => { "url" => "https://cdn.example.test/partner.png" } })
    jpeg = Vips::Image.black(20, 10).new_from_image([255, 0, 0]).write_to_buffer(".jpg")

    Dir.mktmpdir do |dir|
      described_class.new(manifest: subject, host: "https://example.test", root: dir,
                          browser_class: browser_class, fetcher: ->(_url) { jpeg },
                          out: StringIO.new).capture
      result = File.binread(File.join(dir, "shots/partner.png"))

      expect(result).to start_with("\x89PNG".b)
    end

    expect(browser_class).not_to have_received(:new)
  end

  it "downloads the image selected on a page" do
    subject = manifest("shots" => {}, "images" => { "rival" => {
                         "page" => "https://rival.example.test/pricing", "selector" => ".hero img"
                       } })
    fetcher = class_double(Proofsheet::Download)
    allow(browser).to receive(:image_url_for)
      .with(".hero img")
      .and_return("https://cdn.rival.example.test/hero.svg")
    allow(fetcher).to receive(:call)
      .with("https://cdn.rival.example.test/hero.svg")
      .and_return('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10"/></svg>')

    Dir.mktmpdir do |dir|
      described_class.new(manifest: subject, host: "https://example.test", root: dir,
                          browser_class: browser_class, fetcher: fetcher, out: StringIO.new).capture
      result = File.binread(File.join(dir, "shots/rival.png"))

      expect(result).to start_with("\x89PNG".b)
    end

    expect(browser).to have_received(:visit).with("https://rival.example.test/pricing")
    expect(browser).not_to have_received(:screenshot_png)
  end

  it "refuses downloaded data that is not an image" do
    subject = manifest("shots" => {},
                       "images" => { "broken" => { "url" => "https://cdn.example.test/broken.png" } })

    expect do
      described_class.new(manifest: subject, host: "https://example.test",
                          browser_class: browser_class, fetcher: ->(_url) { "not an image" },
                          out: StringIO.new).capture
    end.to raise_error(Proofsheet::Error, /broken: downloaded data is not a supported image/)
  end

  it "signs in and verifies the configured identity" do
    subject = manifest(
      "credentials" => { "username" => "env:USER", "password" => "env:PASSWORD" },
      "login" => { "path" => "/sign-in", "username_field" => "email",
                   "password_field" => "password", "submit" => "Sign in",
                   "expect" => { "selector" => "header", "text" => "demo@example.com" } }
    )
    credentials = instance_double(Proofsheet::Credentials,
                                  username: "demo@example.com", password: "secret")
    allow(browser).to receive(:sign_in)
    allow(browser).to receive(:shows?).and_return(true)

    Dir.mktmpdir do |dir|
      described_class.new(manifest: subject, host: "https://example.test", root: dir,
                          credentials: credentials, browser_class: browser_class,
                          out: StringIO.new).capture
    end

    expect(browser).to have_received(:sign_in)
      .with(subject.login, "demo@example.com", "secret")
    expect(browser).to have_received(:shows?).with("header", "demo@example.com")
  end

  it "refuses unexpected credentials before starting the browser" do
    subject = manifest(
      "expect" => { "username" => "demo@example.com" },
      "credentials" => { "username" => "env:USER", "password" => "env:PASSWORD" },
      "login" => { "path" => "/sign-in", "username_field" => "email",
                   "password_field" => "password", "submit" => "Sign in" }
    )
    credentials = instance_double(Proofsheet::Credentials, username: "customer@example.com")

    expect(browser_class).not_to receive(:new)
    expect do
      described_class.new(manifest: subject, host: "https://example.test",
                          credentials: credentials, browser_class: browser_class).capture
    end.to raise_error(Proofsheet::Error, /manifest expects "demo@example.com"/)
  end
end
