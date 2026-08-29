#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems"

module XomoReleaseContract
  EXPECTED_BUNDLE_ID = "im.some.xomo"
  EXPECTED_CHINESE_BRAND = "Xomo"
  MINIMUM_MACOS_VERSION = Gem::Version.new("13.0")

  module_function

  def collect(root)
    project = read(root, "veilpic.xcodeproj/project.pbxproj")
    app_source = read(root, "veilpic/AppModels.swift")
    cli_source = read(root, "xomo-cli/Sources/XomoCLI/main.swift")
    cli_release = read(root, "scripts/build_xomo_cli_release.sh")
    release = read(root, "scripts/release.sh")
    isolated_tests = read(root, "scripts/run_tests_isolated.rb")
    adhoc_sign = read(root, "scripts/adhoc_sign_debug_product.sh")
    release_entitlements = read(root, "veilpic/Release.entitlements")
    chinese_info = read(root, "veilpic/zh-Hans.lproj/InfoPlist.strings")
    chinese_strings = read(root, "veilpic/zh-Hans.lproj/Localizable.strings")

    app_version = app_source[/static let current = "([^"]+)"/, 1]
    cli_version = cli_source[/xomoCLIVersion = "([^"]+)"/, 1]
    project_versions = project.scan(/MARKETING_VERSION = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    build_versions = project.scan(/CURRENT_PROJECT_VERSION = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    bundle_ids = project.scan(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    deployment_targets = project.scan(/MACOSX_DEPLOYMENT_TARGET = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    user_script_sandboxing = project.scan(/ENABLE_USER_SCRIPT_SANDBOXING = ([^;]+);/).flatten.map { |value| value.strip.delete('"') }.uniq
    expected_build_version = app_version&.match(/-rc(\d+)\z/)&.[](1)
    app_release_settings = project.scan(/buildSettings = \{\n(.*?)\n\s*\};/m).flatten.find do |settings|
      settings.include?("CODE_SIGN_ENTITLEMENTS = veilpic/Release.entitlements;")
    end

    checks = {
      "app_and_cli_version_match" => !app_version.nil? && app_version == cli_version,
      "project_versions_match" => !project_versions.empty? && project_versions == [app_version],
      "build_version_matches_prerelease" => !expected_build_version.nil? && build_versions == [expected_build_version],
      "main_bundle_id" => bundle_ids.include?(EXPECTED_BUNDLE_ID),
      "chinese_bundle_name_is_xomo" =>
        chinese_info.include?(%Q{"CFBundleDisplayName" = "#{EXPECTED_CHINESE_BRAND}";}) &&
        chinese_info.include?(%Q{"CFBundleName" = "#{EXPECTED_CHINESE_BRAND}";}),
      "chinese_app_name_is_xomo" =>
        chinese_strings.include?(%Q{"app.name" = "#{EXPECTED_CHINESE_BRAND}";}),
      "test_bundle_ids" => bundle_ids.include?("#{EXPECTED_BUNDLE_ID}Tests") && bundle_ids.include?("#{EXPECTED_BUNDLE_ID}UITests"),
      "minimum_macos_13" => !deployment_targets.empty? && deployment_targets.all? { |value| Gem::Version.new(value) >= MINIMUM_MACOS_VERSION },
      "cli_release_is_universal" => cli_release.include?("--arch arm64") && cli_release.include?("--arch x86_64"),
      "release_entrypoint_present" => release.include?("xcodebuild") && release.include?("-exportArchive"),
      "isolated_test_entrypoint_present" => isolated_tests.include?("build-for-testing") && isolated_tests.include?("test-without-building"),
      "signing_script_has_required_file_access" => user_script_sandboxing == ["NO"],
      "ui_test_runner_signing_is_left_to_xcode" =>
        adhoc_sign.include?("im.some.xomoUITests") &&
        adhoc_sign.include?('PRODUCT_BUNDLE_IDENTIFIER:-'),
      "release_signing_requests_secure_timestamp" =>
        !app_release_settings.nil? && app_release_settings.include?('OTHER_CODE_SIGN_FLAGS = "--timestamp";'),
      "release_entitlements_are_hardened" =>
        release_entitlements.include?("com.apple.security.app-sandbox") &&
        release_entitlements.include?("com.apple.security.files.user-selected.read-write") &&
        release_entitlements.include?("com.apple.security.network.client") &&
        !release_entitlements.include?("com.apple.security.get-task-allow"),
    }

    {
      "version" => app_version,
      "project_versions" => project_versions,
      "build_versions" => build_versions,
      "bundle_ids" => bundle_ids,
      "deployment_targets" => deployment_targets,
      "user_script_sandboxing" => user_script_sandboxing,
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
