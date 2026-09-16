# frozen_string_literal: true

require_relative "proofsheet/version"

module Proofsheet
  class Error < StandardError
  end
end

require_relative "proofsheet/browser"
require_relative "proofsheet/clip"
require_relative "proofsheet/credentials"
require_relative "proofsheet/manifest"
require_relative "proofsheet/capturer"
require_relative "proofsheet/cli"
