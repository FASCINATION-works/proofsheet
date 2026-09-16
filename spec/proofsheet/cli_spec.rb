# frozen_string_literal: true

RSpec.describe Proofsheet::CLI do
  def run(argv, manifest)
    out = StringIO.new
    err = StringIO.new
    status = described_class.new(argv, out: out, err: err, root: "/project",
                                       manifest_loader: ->(_path) { manifest }, capturer_class: capturer_class).run
    [status, out.string, err.string]
  end

  let(:manifest) do
    Proofsheet::Manifest.new({
                               "host" => "https://example.test",
                               "shots" => { "home" => { "path" => "/" }, "account" => { "path" => "/account" } }
                             })
  end
  let(:capturer_class) do
    Class.new do
      class << self
        attr_accessor :last
      end

      attr_reader :arguments, :names

      def initialize(**arguments)
        @arguments = arguments
        self.class.last = self
      end

      def capture(names)
        @names = names
      end
    end
  end

  it "lists the configured shots" do
    status, out, = run(["list"], manifest)

    expect(status).to eq(0)
    expect(out).to include("home", "/", "account", "/account")
  end

  it "captures only named shots" do
    status, = run(%w[capture account], manifest)

    expect(status).to eq(0)
    expect(capturer_class.last.names).to eq(["account"])
  end

  it "lets the command line override the host" do
    run(["capture", "--host", "http://localhost:3000"], manifest)

    expect(capturer_class.last.arguments).to include(host: "http://localhost:3000")
  end

  it "returns a failure for an unknown command" do
    status, _, err = run(["unknown"], manifest)

    expect(status).to eq(1)
    expect(err).to include("Usage: proofsheet")
  end
end
