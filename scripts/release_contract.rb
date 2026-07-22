#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems"

module XomoReleaseContract
  EXPECTED_BUNDLE_ID = "im.some.xomo"
  MINIMUM_MACOS_VERSION = Gem::Version.new("13.0")

  module_function

  def collect(root)
    project = read(root, "veilpic.xcodeproj/project.pbxproj")
    app_source = read(root, "veilpic/AppModels.swift")
    cli_source = read(root, "xomo-cli/Sources/XomoCLI/main.swift")
    cli_release = read(root, "scripts/build_xomo_cli_release.sh")
    release = read(root, "scripts/release.sh")
    isolated_tests = read(root, "scripts/run_tests_isolated.rb")

    app_version = app_source[/static let current = "([^"]+)"/, 1]
    cli_version = cli_source[/xomoCLIVersion = "([^"]+)"/, 1]
    project_versions = project.scan(/MARKETING_VERSION = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    build_versions = project.scan(/CURRENT_PROJECT_VERSION = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    bundle_ids = project.scan(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    deployment_targets = project.scan(/MACOSX_DEPLOYMENT_TARGET = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    expected_build_version = app_version&.match(/-rc(\d+)\z/)&.[](1)

    checks = {
      "app_and_cli_version_match" => !app_version.nil? && app_version == cli_version,
      "project_versions_match" => !project_versions.empty? && project_versions == [app_version],
      "build_version_matches_prerelease" => !expected_build_version.nil? && build_versions == [expected_build_version],
      "main_bundle_id" => bundle_ids.include?(EXPECTED_BUNDLE_ID),
      "test_bundle_ids" => bundle_ids.include?("#{EXPECTED_BUNDLE_ID}Tests") && bundle_ids.include?("#{EXPECTED_BUNDLE_ID}UITests"),
      "minimum_macos_13" => !deployment_targets.empty? && deployment_targets.all? { |value| Gem::Version.new(value) >= MINIMUM_MACOS_VERSION },
      "cli_release_is_universal" => cli_release.include?("--arch arm64") && cli_release.include?("--arch x86_64"),
      "release_entrypoint_present" => release.include?("xcodebuild") && release.include?("-exportArchive"),
      "isolated_test_entrypoint_present" => isolated_tests.include?("build-for-testing") && isolated_tests.include?("test-without-building"),
    }

    {
      "version" => app_version,
      "project_versions" => project_versions,
      "build_versions" => build_versions,
      "bundle_ids" => bundle_ids,
      "deployment_targets" => deployment_targets,
      "checks" => checks,
      "passed" => checks.values.all?
    }
  rescue Errno::ENOENT => error
    {
      "version" => nil,
      "project_versions" => [],
      "build_versions" => [],
      "bundle_ids" => [],
      "deployment_targets" => [],
      "checks" => { "repository_files_present" => false },
      "passed" => false,
      "error" => error.message
    }
  end

  def read(root, relative_path)
    File.read(File.join(root, relative_path), encoding: "UTF-8")
  end
end
