# frozen_string_literal: true

RSpec.describe Proofsheet::Credentials do
  def credentials(config, env: {}, &reader)
    described_class.new(config, env: env, reader: reader || ->(*) { raise "unexpected read" })
  end

  it "reads credentials from the environment" do
    config = { "username" => "env:PROOF_USER", "password" => "env:PROOF_PASSWORD" }
    subject = credentials(config, env: { "PROOF_USER" => "marc@example.com", "PROOF_PASSWORD" => "secret" })

    expect([subject.username, subject.password]).to eq(["marc@example.com", "secret"])
  end

  it "reads 1Password references with the configured account" do
    asked = []
    config = { "op_account" => "ACCT", "username" => "op://Vault/Item/username",
               "password" => "op://Vault/Item/password" }
    subject = credentials(config) do |account, reference|
      asked << [account, reference]
      "value\n"
    end

    expect([subject.username, subject.password]).to eq(%w[value value])
    expect(asked).to eq([
                          ["ACCT", "op://Vault/Item/username"],
                          ["ACCT", "op://Vault/Item/password"]
                        ])
  end

  it "rejects credential values stored directly in the manifest" do
    subject = credentials({ "username" => "marc@example.com", "password" => "secret" })

    expect { subject.username }.to raise_error(Proofsheet::Error, /credential sources/)
  end

  it "rejects blank credentials" do
    subject = credentials({ "username" => "env:PROOF_USER", "password" => "env:PROOF_PASSWORD" },
                          env: { "PROOF_USER" => "\n", "PROOF_PASSWORD" => "secret" })

    expect { subject.username }.to raise_error(Proofsheet::Error, /is empty/)
  end

  describe ".op_read" do
    def status(success)
      instance_double(Process::Status, success?: success)
    end

    it "passes the account and reference as arguments without a shell" do
      allow(Open3).to receive(:capture3).and_return(["secret\n", "", status(true)])

      result = described_class.op_read("ACCT", "op://Vault/Item/password")

      expect(result).to eq("secret\n")
      expect(Open3).to have_received(:capture3)
        .with("op", "read", "--account", "ACCT", "op://Vault/Item/password")
    end

    it "surfaces errors from 1Password" do
      allow(Open3).to receive(:capture3).and_return(["", "not signed in\n", status(false)])

      expect { described_class.op_read(nil, "op://Vault/Item/username") }
        .to raise_error(Proofsheet::Error, /not signed in/)
    end
  end
end
