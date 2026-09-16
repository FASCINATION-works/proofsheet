# frozen_string_literal: true

RSpec.describe Proofsheet::Manifest do
  def manifest(overrides = {})
    described_class.new({
      "host" => "https://example.test",
      "targets" => { "account" => 12 },
      "defaults" => { "viewport" => [1280, 800], "output_dir" => "docs/images" },
      "shots" => {
        "plain" => { "path" => "/about" },
        "targeted" => {
          "path" => "/accounts/%{account}",
          "wait_for" => ".loaded",
          "click" => ".expand",
          "expect" => { "selector" => ".account", "text" => "Example Co" },
          "clip" => { "selector" => ".chart", "full_width" => true, "padding" => 5 }
        }
      }
    }.merge(overrides))
  end

  it "reads capture defaults and shot definitions" do
    shot = manifest.shot("targeted")

    expect(manifest).to have_attributes(host: "https://example.test", viewport: [1280, 800],
                                        output_dir: "docs/images")
    expect(shot).to have_attributes(name: "targeted", wait_for: ".loaded", click: ".expand",
                                    filename: "targeted.png", clip?: true)
    expect(shot.clip).to have_attributes(selector: ".chart", full_width: true, padding: 5)
    expect(shot.expectation).to have_attributes(selector: ".account", text: "Example Co")
  end

  it "substitutes targets into paths" do
    subject = manifest

    expect(subject.path_for(subject.shot("targeted"))).to eq("/accounts/12")
  end

  it "reports an unset target" do
    subject = manifest("targets" => { "account" => nil })

    expect { subject.path_for(subject.shot("targeted")) }
      .to raise_error(Proofsheet::Error, /targets\.account is not set/)
  end

  it "reports an unknown shot" do
    expect { manifest.shot("missing") }.to raise_error(Proofsheet::Error, /unknown shot "missing"/)
  end

  it "supports projects that do not require a login" do
    expect(manifest.login).to be_nil
  end

  it "reads a configurable login" do
    subject = manifest("login" => {
                         "path" => "/sign-in",
                         "username_field" => "email",
                         "password_field" => "password",
                         "submit" => "Continue",
                         "expect" => { "selector" => "header", "text" => "marc@example.com" }
                       })

    expect(subject.login).to have_attributes(path: "/sign-in", username_field: "email",
                                             password_field: "password", submit: "Continue")
    expect(subject.login.expectation).to have_attributes(selector: "header", text: "marc@example.com")
  end

  it "reads composition backgrounds and screenshot layers" do
    subject = manifest("compositions" => {
                         "hero" => {
                           "canvas" => [1600, 1000],
                           "background" => { "gradient" => ["#112233", "#ddeeff"], "angle" => 135 },
                           "layers" => [{
                             "shot" => "targeted", "x" => 120, "y" => 80,
                             "crop" => { "x" => 10, "y" => 20, "width" => 1000, "height" => 600 },
                             "width" => 900, "radius" => 32, "rotate" => -4,
                             "shadow" => { "x" => 8, "y" => 20, "blur" => 30, "color" => "#00000066" }
                           }]
                         }
                       })

    composition = subject.composition("hero")

    expect(composition).to have_attributes(name: "hero", width: 1600, height: 1000, filename: "hero.png")
    expect(composition.background).to have_attributes(gradient: ["#112233", "#ddeeff"], angle: 135)
    expect(composition.layers.first).to have_attributes(shot: "targeted", x: 120, y: 80,
                                                        width: 900, radius: 32, rotate: -4)
    expect(composition.layers.first.crop).to have_attributes(x: 10, y: 20, width: 1000, height: 600)
    expect(composition.layers.first.shadow).to have_attributes(x: 8, y: 20, blur: 30, color: "#00000066")
  end

  it "reports an unknown composition" do
    expect { manifest.composition("missing") }
      .to raise_error(Proofsheet::Error, /unknown composition "missing"/)
  end
end
