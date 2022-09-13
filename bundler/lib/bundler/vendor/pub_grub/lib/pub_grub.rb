require "bundler/vendor/pub_grub/lib/pub_grub/package"
require "bundler/vendor/pub_grub/lib/pub_grub/static_package_source"
require "bundler/vendor/pub_grub/lib/pub_grub/term"
require "bundler/vendor/pub_grub/lib/pub_grub/version_range"
require "bundler/vendor/pub_grub/lib/pub_grub/version_constraint"
require "bundler/vendor/pub_grub/lib/pub_grub/version_union"
require "bundler/vendor/pub_grub/lib/pub_grub/version_solver"
require "bundler/vendor/pub_grub/lib/pub_grub/incompatibility"
require 'bundler/vendor/pub_grub/lib/pub_grub/solve_failure'
require 'bundler/vendor/pub_grub/lib/pub_grub/failure_writer'
require 'bundler/vendor/pub_grub/lib/pub_grub/version'

module Bundler::PubGrub
  class << self
    attr_writer :logger

    def logger
      @logger || default_logger
    end

    private

    def default_logger
      require "logger"

      logger = ::Logger.new(STDERR)
      logger.level = ENV["DEBUG"] ? ::Logger::DEBUG : ::Logger::WARN
      @logger = logger
    end
  end
end
