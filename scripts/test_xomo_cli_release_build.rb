#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class XomoCLIReleaseBuildTest < Minitest::Test
  VERSION = '2.12.0-rc1778'
  SCRIPT = File.expand_path('build_xomo_cli_release.sh', __dir__)

  def test_uses_reported_output_instead_of_stale_legacy_binary
    with_fixture do |root, env|
      stdout, stderr, status = run_build(root, env)
      assert status.success?, stderr
      assert_equal VERSION, binary_version(File.join(root, 'dist/xomo-macos-universal'))
      calls = File.readlines(File.join(root, 'swift-calls.jsonl')).map { |line| JSON.parse(line) }
      assert_equal 2, calls.length
      assert_equal calls.first + ['--show-bin-path'], calls.last
      arches = File.readlines(File.join(root, 'lipo-calls.jsonl')).map { |line| JSON.parse(line).last }
      assert_equal %w[arm64 x86_64], arches
      assert_includes stdout, VERSION
    end
  end

  def test_stale_reported_binary_is_rejected_without_overwriting_delivery
    with_fixture(version: '2.12.0-rc1200') do |root, env|
      _stdout, stderr, status = run_build(root, env)
      refute status.success?
      assert_includes stderr, 'version mismatch'
      assert_delivery_preserved(root)
    end
  end

  def test_missing_reported_binary_does_not_fall_back_to_legacy_output
    with_fixture(missing: true) do |root, env|
      _stdout, stderr, status = run_build(root, env)
      refute status.success?
      assert_includes stderr, 'Missing built CLI'
      assert_delivery_preserved(root)
    end
  end

  def test_single_architecture_is_rejected_without_overwriting_delivery
    with_fixture do |root, env|
      _stdout, _stderr, status = run_build(root, env.merge('XOMO_FIXTURE_BAD_ARCH' => '1'))
      refute status.success?
      assert_delivery_preserved(root)
    end
  end

  def test_build_failure_does_not_copy_any_cached_binary
    with_fixture do |root, env|
      _stdout, _stderr, status = run_build(root, env.merge('XOMO_FIXTURE_BUILD_FAILURE' => '1'))
      refute status.success?
      assert_delivery_preserved(root)
    end
  end

  def test_failed_path_query_cannot_deliver_its_partial_output
    with_fixture do |root, env|
      _stdout, _stderr, status = run_build(root, env.merge('XOMO_FIXTURE_QUERY_FAILURE' => '1'))
      refute status.success?
      assert_delivery_preserved(root)
    end
  end

  def test_failed_version_command_cannot_deliver_its_partial_output
    with_fixture do |root, env|
      _stdout, _stderr, status = run_build(root, env.merge('XOMO_FIXTURE_VERSION_FAILURE' => '1'))
      refute status.success?
      assert_delivery_preserved(root)
    end
  end

  private

  def with_fixture(version: VERSION, missing: false)
    Dir.mktmpdir('xomo-cli-release ') do |root|
      %w[scripts bin dist xomo-cli/Sources/XomoCLI].each { |path| FileUtils.mkdir_p(File.join(root, path)) }
      FileUtils.cp(SCRIPT, File.join(root, 'scripts/build_xomo_cli_release.sh'))
      File.write(File.join(root, 'xomo-cli/Sources/XomoCLI/main.swift'),
                 "private let xomoCLIVersion = \"#{VERSION}\"\n")
      File.write(File.join(root, 'dist/xomo-macos-universal'), 'existing-delivery')
      output = File.join(root, 'xomo-cli/.build/new output/Products/Release')
      FileUtils.mkdir_p(output)
      write_binary(File.join(output, 'xomo'), version) unless missing
      legacy = File.join(root, 'xomo-cli/.build/apple/Products/Release')
      FileUtils.mkdir_p(legacy)
      write_binary(File.join(legacy, 'xomo'), '2.12.0-rc1200')
      swift = [
        '#!/usr/bin/ruby', "require 'json'",
        "File.open(ENV.fetch('XOMO_FIXTURE_CALLS'), 'a') { |f| f.puts(JSON.generate(ARGV)) }",
        "exit 65 if ENV['XOMO_FIXTURE_BUILD_FAILURE'] == '1'",
        "if ARGV.include?('--show-bin-path')",
        "  puts ENV.fetch('XOMO_FIXTURE_OUTPUT')",
        "  exit 65 if ENV['XOMO_FIXTURE_QUERY_FAILURE'] == '1'",
        'end'
      ].join("\n") + "\n"
      File.write(File.join(root, 'bin/swift'), swift)
      File.write(File.join(root, 'bin/lipo'),
                 [ '#!/usr/bin/ruby',
                   "require 'json'",
                   "expected = [ENV.fetch('XOMO_FIXTURE_OUTPUT') + '/xomo', '-verify_arch']",
                   "exit 2 unless ARGV.size == 3 && ARGV.first(2) == expected && %w[arm64 x86_64].include?(ARGV.last)",
                   "File.open(ENV.fetch('XOMO_FIXTURE_ARCH_CALLS'), 'a') { |f| f.puts(JSON.generate(ARGV)) }",
                   "exit(ENV['XOMO_FIXTURE_BAD_ARCH'] == '1' && ARGV.last == 'x86_64' ? 1 : 0)" ].join("\n") + "\n")
      FileUtils.chmod(0o755, [File.join(root, 'bin/swift'), File.join(root, 'bin/lipo')])
      yield root, { 'PATH' => File.join(root, 'bin') + ':' + ENV.fetch('PATH'),
                    'XOMO_FIXTURE_CALLS' => File.join(root, 'swift-calls.jsonl'),
                    'XOMO_FIXTURE_ARCH_CALLS' => File.join(root, 'lipo-calls.jsonl'),
                    'XOMO_FIXTURE_OUTPUT' => output }
    end
  end

  def write_binary(path, version)
    File.write(path, "#!/usr/bin/ruby\nputs #{version.inspect}\nexit 1 if ENV['XOMO_FIXTURE_VERSION_FAILURE'] == '1'\n")
    FileUtils.chmod(0o755, path)
  end

  def run_build(root, env)
    Open3.capture3(env, 'bash', File.join(root, 'scripts/build_xomo_cli_release.sh'))
  end

  def binary_version(path)
    stdout, stderr, status = Open3.capture3(path, 'version')
    assert status.success?, stderr
    stdout.strip
  end

  def assert_delivery_preserved(root)
    assert_equal 'existing-delivery', File.read(File.join(root, 'dist/xomo-macos-universal'))
  end
end
