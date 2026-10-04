#!/usr/bin/env ruby
require 'json'
require 'digest'
require 'open3'
require 'fileutils'

root = File.expand_path('..', __dir__)
output = File.expand_path(ARGV.fetch(0))
raise 'Use a fresh output directory' unless Dir.exist?(output) && Dir.empty?(output)
production = File.join(root, 'veilpic/ImageEditorLayerAdvancedControlsViewport.swift')
fixture = File.join(root, 'veilpicTests/ImageEditorLayerAdvancedControlsLayoutTests.swift')
binary = File.join(output, 'layout-tests')
command = ['xcrun', 'swiftc', '-D', 'XOMO_STANDALONE_LAYOUT_TESTS', production, fixture,
           '-o', binary, '-framework', 'AppKit', '-framework', 'SwiftUI']

File.open('/private/tmp/veilpic-build.lock', File::RDWR | File::CREAT, 0o600) do |lock|
  raise 'Another native build owns the lock' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  stdout, stderr, status = Open3.capture3(*command)
  File.write(File.join(output, 'compile.log'), stdout + stderr)
  raise "Production layout test compile failed: #{stderr}" unless status.success?
  result, runtime_stderr, runtime_status = Open3.capture3(binary)
  File.write(File.join(output, 'runtime.log'), result + runtime_stderr)
  measurements = JSON.parse(result)
  report = measurements.merge(
    'scope' => 'Production SwiftUI viewport with hosted list/disclosure fixture; not full panel or GUI acceptance',
    'command' => command, 'compile_exit' => status.exitstatus, 'runtime_exit' => runtime_status.exitstatus,
    'seconds' => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3),
    'production_sha256' => Digest::SHA256.file(production).hexdigest,
    'fixture_sha256' => Digest::SHA256.file(fixture).hexdigest,
    'compile_stderr' => stderr, 'runtime_stderr' => runtime_stderr,
    'shared_xctest_service_used_or_restarted' => false)
  File.write(File.join(output, 'report.json'), JSON.pretty_generate(report) + "\n")
  rows = report.fetch('cases').map do |c|
    "| #{c['width']} | #{c['rows']} | #{c['expanded_viewport_height']} | #{c['expanded_list_height']} | #{c['collapsed_list_height']} | #{c['passed']} |"
  end
  File.write(File.join(output, 'report.md'), "# Production property viewport layout\n\n#{report['scope']}\n\n" \
    "| Width | Rows | Viewport | Expanded list | Collapsed list | Passed |\n|---|---|---|---|---|---|\n" + rows.join("\n") + "\n")
  puts JSON.generate(report.reject { |key, _| %w[cases compile_stderr runtime_stderr].include?(key) })
  exit(runtime_status.exitstatus) unless runtime_status.success? && report['passed']
end
