# frozen_string_literal: true

module Bundler
  class Resolver
    class Package
      attr_reader :name, :locked_version
      attr_accessor :platforms

      def initialize(name, platforms, locked_version, unlock, force_ruby_platform = false, prerelease_specified = false)
        @name = name
        @platforms = platforms
        @locked_version = locked_version
        @unlock = unlock
        @force_ruby_platform = force_ruby_platform
        @prerelease_specified = prerelease_specified
      end

      def to_s
        @name
      end

      def ==(other)
        @name == other.name
      end

      def hash
        @name.hash
      end

      def unlock?
        @unlock
      end

      def force_ruby_platform?
        @force_ruby_platform
      end

      def prerelease_specified?
        @prerelease_specified
      end
    end
  end
end
