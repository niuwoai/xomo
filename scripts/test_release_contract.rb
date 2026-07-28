#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "release_contract"

class ReleaseContractTest < Minitest::Test
  def test_current_repository_passes
    result = XomoReleaseContract.collect(File.expand_path("..", __dir__))

    assert result["passed"], result.inspect
    assert_equal "2.12.0-rc546", result["version"]
    assert_equal ["2.12.0-rc546"], result["project_versions"]
    assert_equal ["546"], result["build_versions"]
  end

  def test_version_drift_fails_the_contract
    with_fixture do |root|
      write_fixture(root, version: "2.12.0-rc285", cli_version: "2.12.0-rc284")

      result = XomoReleaseContract.collect(root)

      refute result["passed"]
      refute result["checks"]["app_and_cli_version_match"]
    end
  end

  def test_old_deployment_target_fails_the_contract
    with_fixture do |root|
      write_fixture(root, deployment_target: "12.0")

      result = XomoReleaseContract.collect(root)

      refute result["passed"]
      refute result["checks"]["minimum_macos_13"]
    end
  end

  def test_prerelease_build_number_drift_fails_the_contract
    with_fixture do |root|
      write_fixture(root, version: "2.12.0-rc285", build_version: "284")

      result = XomoReleaseContract.collect(root)

      refute result["passed"]
      refute result["checks"]["build_version_matches_prerelease"]
    end
  end

  private

  def with_fixture
    Dir.mktmpdir("xomo-release-contract") { |root| yield root }
  end

  def write_fixture(
    root,
    version: "2.12.0-rc285",
    cli_version: version,
    deployment_target: "13.0",
    build_version: version[/-rc(\d+)\z/, 1]
  )
    FileUtils.mkdir_p(File.join(root, "veilpic.xcodeproj"))
    FileUtils.mkdir_p(File.join(root, "veilpic"))
    FileUtils.mkdir_p(File.join(root, "xomo-cli/Sources/XomoCLI"))
    FileUtils.mkdir_p(File.join(root, "scripts"))

    File.write(File.join(root, "veilpic/AppModels.swift"), "enum AppVersion { static let current = \"#{version}\" }\n")
    File.write(File.join(root, "xomo-cli/Sources/XomoCLI/main.swift"), "private let xomoCLIVersion = \"#{cli_version}\"\n")
    File.write(File.join(root, "veilpic.xcodeproj/project.pbxproj"), <<~PBX)
      CURRENT_PROJECT_VERSION = #{build_version};
      MACOSX_DEPLOYMENT_TARGET = #{deployment_target};
      MARKETING_VERSION = #{version};
      PRODUCT_BUNDLE_IDENTIFIER = im.some.xomo;
      PRODUCT_BUNDLE_IDENTIFIER = im.some.xomoTests;
      PRODUCT_BUNDLE_IDENTIFIER = im.some.xomoUITests;
    PBX
    File.write(File.join(root, "scripts/build_xomo_cli_release.sh"), "swift build --arch arm64 --arch x86_64\n")
    File.write(File.join(root, "scripts/release.sh"), "xcodebuild archive\nxcodebuild -exportArchive\n")
    File.write(File.join(root, "scripts/run_tests_isolated.rb"), "build-for-testing\ntest-without-building\n")
  end
end
