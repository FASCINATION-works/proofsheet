# frozen_string_literal: true

require "open-uri"
require "socket"

module Proofsheet
  class Download
    FAILURES = [URI::InvalidURIError, OpenURI::HTTPError, RuntimeError, SystemCallError, SocketError].freeze

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s
    end

    def call
      uri = URI.parse(@url)
      raise Error, "#{@url.inspect} is not an http or https URL" unless uri.is_a?(URI::HTTP)

      uri.read
    rescue *FAILURES => e
      raise Error, "could not fetch #{@url}: #{e.message}"
    end
  end
end
