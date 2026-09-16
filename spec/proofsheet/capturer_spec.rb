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
