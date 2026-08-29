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
    assert_equal "2.12.0-rc1427", result["version"]
    assert_equal ["2.12.0-rc1427"], result["project_versions"]
    assert_equal ["1427"], result["build_versions"]
    assert result["checks"]["release_signing_requests_secure_timestamp"]
    assert result["checks"]["release_entitlements_are_hardened"]
    assert result["checks"]["chinese_bundle_name_is_xomo"]
    assert result["checks"]["chinese_app_name_is_xomo"]
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

  def test_debuggable_release_entitlements_fail_the_contract
    with_fixture do |root|
      write_fixture(root, release_debuggable: true)

      result = XomoReleaseContract.collect(root)

      refute result["passed"]
      refute result["checks"]["release_entitlements_are_hardened"]
    end
  end

  def test_missing_secure_timestamp_fails_the_contract
    with_fixture do |root|
      write_fixture(root, secure_timestamp: false)

      result = XomoReleaseContract.collect(root)

      refute result["passed"]
      refute result["checks"]["release_signing_requests_secure_timestamp"]
    end
  end

  def test_legacy_chinese_brand_fails_the_contract
    with_fixture do |root|
      write_fixture(root, chinese_brand: "像界")

      result = XomoReleaseContract.collect(root)

      refute result["passed"]
      refute result["checks"]["chinese_bundle_name_is_xomo"]
      refute result["checks"]["chinese_app_name_is_xomo"]
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
    build_version: version[/-rc(\d+)\z/, 1],
    release_debuggable: false,
    secure_timestamp: true,
    chinese_brand: "Xomo"
  )
    FileUtils.mkdir_p(File.join(root, "veilpic.xcodeproj"))
    FileUtils.mkdir_p(File.join(root, "veilpic"))
    FileUtils.mkdir_p(File.join(root, "veilpic/zh-Hans.lproj"))
    FileUtils.mkdir_p(File.join(root, "xomo-cli/Sources/XomoCLI"))
    FileUtils.mkdir_p(File.join(root, "scripts"))

    File.write(File.join(root, "veilpic/AppModels.swift"), "enum AppVersion { static let current = \"#{version}\" }\n")
    File.write(File.join(root, "xomo-cli/Sources/XomoCLI/main.swift"), "private let xomoCLIVersion = \"#{cli_version}\"\n")
    File.write(File.join(root, "veilpic.xcodeproj/project.pbxproj"), <<~PBX)
      buildSettings = {
        CODE_SIGN_ENTITLEMENTS = veilpic/Release.entitlements;
        CURRENT_PROJECT_VERSION = #{build_version};
        MACOSX_DEPLOYMENT_TARGET = #{deployment_target};
        MARKETING_VERSION = #{version};
        PRODUCT_BUNDLE_IDENTIFIER = im.some.xomo;
        PRODUCT_BUNDLE_IDENTIFIER = im.some.xomoTests;
        PRODUCT_BUNDLE_IDENTIFIER = im.some.xomoUITests;
        #{"OTHER_CODE_SIGN_FLAGS = \"--timestamp\";" if secure_timestamp}
      };
    PBX
    File.write(File.join(root, "scripts/build_xomo_cli_release.sh"), "swift build --arch arm64 --arch x86_64\n")
    File.write(File.join(root, "scripts/release.sh"), "xcodebuild archive\nxcodebuild -exportArchive\n")
    File.write(File.join(root, "scripts/run_tests_isolated.rb"), "build-for-testing\ntest-without-building\n")
    File.write(
      File.join(root, "veilpic/zh-Hans.lproj/InfoPlist.strings"),
      %Q{"CFBundleDisplayName" = "#{chinese_brand}";\n"CFBundleName" = "#{chinese_brand}";\n}
    )
    File.write(
      File.join(root, "veilpic/zh-Hans.lproj/Localizable.strings"),
      %Q{"app.name" = "#{chinese_brand}";\n}
    )
    debug_entitlement = release_debuggable ? "<key>com.apple.security.get-task-allow</key><true/>" : ""
    File.write(File.join(root, "veilpic/Release.entitlements"), <<~PLIST)
      <plist><dict>
      <key>com.apple.security.app-sandbox</key><true/>
      <key>com.apple.security.files.user-selected.read-write</key><true/>
      <key>com.apple.security.network.client</key><true/>
      #{debug_entitlement}
      </dict></plist>
    PLIST
  end
end
