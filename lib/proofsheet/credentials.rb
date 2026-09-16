# frozen_string_literal: true

require "open3"

module Proofsheet
  class Credentials
    def self.op_read(account, reference)
      command = %w[op read]
      command.push("--account", account) unless account.nil?
      out, err, status = Open3.capture3(*command, reference)
      return out if status.success?

      raise Error, "#{reference}: #{err.strip.empty? ? "op read failed" : err.strip}"
    end

    def initialize(config, env: ENV, reader: Credentials.method(:op_read))
      @config = config
      @env = env
      @reader = reader
    end

    def username
      read(@config.fetch("username"))
    end

    def password
      read(@config.fetch("password"))
    end

    private

    def read(source)
      value = case source
              when %r{\Aop://}
                @reader.call(@config["op_account"], source)
              when /\Aenv:(.+)\z/
                @env.fetch(Regexp.last_match(1))
              else
                raise Error, "credential sources must be an env:VARIABLE or op:// reference"
              end

      value.to_s.strip.then { |result| result.empty? ? raise(Error, "#{source} is empty") : result }
    rescue Errno::ENOENT
      raise Error, "the 1Password CLI is not installed"
    rescue KeyError => e
      raise Error, e.message
    end
  end
end
