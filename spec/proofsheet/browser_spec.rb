# frozen_string_literal: true

require "capybara"

RSpec.describe Proofsheet::Browser do
  subject(:browser) do
    described_class.allocate.tap { |instance| instance.instance_variable_set(:@session, session) }
  end

  let(:session) { instance_double(Capybara::Session) }
  let(:node) { instance_double(Capybara::Node::Element) }

  before do
    allow(session).to receive(:find).with(".hero", match: :first).and_return(node)
  end

  it "returns the browser-selected source of an image" do
    allow(node).to receive(:tag_name).and_return("img")
    allow(session).to receive(:evaluate_script)
      .with("arguments[0].currentSrc || arguments[0].src", node)
      .and_return("https://cdn.example.test/hero@2x.webp")

    expect(browser.image_url_for(".hero")).to eq("https://cdn.example.test/hero@2x.webp")
  end

  it "refuses a selector that does not select an image" do
    allow(node).to receive(:tag_name).and_return("div")

    expect { browser.image_url_for(".hero") }
      .to raise_error(Proofsheet::Error, /selected <div>, expected <img>/)
  end

  it "refuses an image without a source" do
    allow(node).to receive(:tag_name).and_return("img")
    allow(session).to receive(:evaluate_script).and_return("")

    expect { browser.image_url_for(".hero") }
      .to raise_error(Proofsheet::Error, /image without a source/)
  end
end
