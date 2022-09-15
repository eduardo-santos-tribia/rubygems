# frozen_string_literal: true

module Bundler
  class Resolver
    require_relative "vendored_pub_grub"
    require_relative "resolver/base"
    require_relative "resolver/package"
    require_relative "resolver/version"

    include GemHelpers

    # Figures out the best possible configuration of gems that satisfies
    # the list of passed dependencies and any child dependencies without
    # causing any gem activation errors.
    #
    # ==== Parameters
    # *dependencies<Gem::Dependency>:: The list of dependencies to resolve
    #
    # ==== Returns
    # <GemBundle>,nil:: If the list of dependencies can be resolved, a
    #   collection of gemspecs is returned. Otherwise, nil is returned.
    def self.resolve(requirements, source_requirements = {}, base = [], gem_version_promoter = GemVersionPromoter.new, additional_base_requirements = [])
      base = SpecSet.new(base) unless base.is_a?(SpecSet)
      resolver = new(source_requirements, base, gem_version_promoter, additional_base_requirements)
      resolver.start(requirements)
    end

    attr_reader :packages

    def initialize(source_requirements, base, gem_version_promoter, additional_base_requirements)
      @source_requirements = source_requirements
      @base = Resolver::Base.new(base, additional_base_requirements)
      @results_for = {}
      @search_for = {}
      @gem_version_promoter = gem_version_promoter
    end

    def start(requirements, packages, exclude_specs: [])
      exclude_specs.each do |spec|
        remove_from_candidates(spec)
      end

      @packages = packages

      requirements = verify_gemfile_dependencies_are_found!(requirements)

      require_relative "resolver/package_source"
      source = Resolver::PackageSource.new(self, requirements, @gem_version_promoter)
      solver = PubGrub::VersionSolver.new(source: source)
      result = solver.solve
      result.map {|package, version| version.to_specs(package.force_ruby_platform?) unless package.name == :root }.compact.flatten.uniq
    end

    def dependencies_for(specification)
      specification.dependencies
    end

    def all_versions_for(package)
      name = package.name
      results = @base[name] + results_for(name)
      locked_requirement = base_requirements[name]
      results = results.select {|spec| requirement_satisfied_by?(locked_requirement, nil, spec) } if locked_requirement

      results.group_by(&:version).reduce([]) do |groups, (version, specs)|
        platform_specs = package.platforms.flat_map {|platform| select_best_platform_match(specs, platform) }.uniq
        next groups if platform_specs.empty?

        ruby_specs = select_best_platform_match(specs, Gem::Platform::RUBY)
        groups << Resolver::Version.new(version, specs: ruby_specs) if ruby_specs.any?

        next groups if platform_specs == ruby_specs

        groups << Resolver::Version.new(version, specs: platform_specs)

        groups
      end
    end

    def search_for(dependency)
      @search_for[dependency] ||= all_versions_for(@packages[dependency.name]).select {|version| requirement_satisfied_by?(dependency, nil, version.spec_group) }
    end

    def index_for(name)
      source_for(name).specs
    end

    def source_for(name)
      @source_requirements[name] || @source_requirements[:default]
    end

    def results_for(name)
      @results_for[name] ||= index_for(name).search(name)
    end

    def requirement_satisfied_by?(requirement, activated, spec)
      requirement.matches_spec?(spec) || spec.source.is_a?(Source::Gemspec)
    end

    private

    def base_requirements
      @base.base_requirements
    end

    def remove_from_candidates(spec)
      @base.delete(spec)

      @results_for.keys.each do |name|
        next unless name == spec.name

        @results_for[name].reject {|s| s.version == spec.version }
      end

      reset_spec_cache
    end

    def reset_spec_cache
      @search_for = {}
    end

    def verify_gemfile_dependencies_are_found!(requirements)
      requirements.map do |requirement|
        name = requirement.name

        next requirement if name == "bundler"
        next requirement unless search_for(requirement).empty?
        next unless requirement.current_platform?

        if (base = @base[name]) && !base.empty?
          version = base.first.version
          message = "You have requested:\n" \
            "  #{name} #{requirement.requirement}\n\n" \
            "The bundle currently has #{name} locked at #{version}.\n" \
            "Try running `bundle update #{name}`\n\n" \
            "If you are updating multiple gems in your Gemfile at once,\n" \
            "try passing them all to `bundle update`"
        else
          message = gem_not_found_message(name, requirement, source_for(name))
        end
        raise GemNotFound, message
      end.compact
    end

    def gem_not_found_message(name, requirement, source, extra_message = "")
      specs = source.specs.search(name).sort_by {|s| [s.version, s.platform.to_s] }
      matching_part = name
      requirement_label = SharedHelpers.pretty_dependency(requirement)
      cache_message = begin
                          " or in gems cached in #{Bundler.settings.app_cache_path}" if Bundler.app_cache.exist?
                        rescue GemfileNotFound
                          nil
                        end
      specs_matching_requirement = specs.select {| spec| requirement.matches_spec?(spec) }

      if specs_matching_requirement.any?
        specs = specs_matching_requirement
        matching_part = requirement_label
        platforms = @packages[name].platforms
        platform_label = platforms.size == 1 ? "platform '#{platforms.first}" : "platforms '#{platforms.join("', '")}"
        requirement_label = "#{requirement_label}' with #{platform_label}"
      end

      message = String.new("Could not find gem '#{requirement_label}'#{extra_message} in #{source}#{cache_message}.\n")

      if specs.any?
        message << "\nThe source contains the following gems matching '#{matching_part}':\n"
        message << specs.map {|s| "  * #{s.full_name}" }.join("\n")
      end

      message
    end
  end
end
