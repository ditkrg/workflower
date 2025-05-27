# frozen_string_literal: true

require_relative "workflower/version"
require "workflower/manager"
require "workflower/acts_as_workflower"

module Workflower
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end

  class Configuration
    attr_accessor :logger

    def initialize
      @logger = nil
    end
  end
end
