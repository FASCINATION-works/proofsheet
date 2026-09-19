# frozen_string_literal: true

RSpec.describe Proofsheet::Download do
  it "refuses a source that is not a URL at all" do
    expect { described_class.call("assets/logo.png") }
      .to raise_error(Proofsheet::Error, /is not an http or https URL/)
  end

  it "refuses a file URL, which open-uri would otherwise read straight off disk" do
    expect { described_class.call("file:///etc/passwd") }
      .to raise_error(Proofsheet::Error, /is not an http or https URL/)
  end
end
