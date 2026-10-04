#!/usr/bin/env ruby
require 'json'
require 'digest'
require 'open3'

root = File.expand_path('..', __dir__)
output = File.expand_path(ARGV.fetch(0))
raise 'Use a fresh empty output directory' unless Dir.exist?(output) && Dir.empty?(output)
production = File.join(root, 'veilpic/ImageEditorLayerBlendIfCompletionOwnership.swift')
fixture = File.join(root, 'veilpicTests/ImageEditorLayerBlendIfCompletionOwnershipTests.swift')
binary = File.join(output, 'completion-tests')
command = ['xcrun', 'swiftc', '-D', 'XOMO_STANDALONE_BLEND_IF_TESTS', production, fixture, '-o', binary]
File.open('/private/tmp/veilpic-build.lock', File::RDWR | File::CREAT, 0o600) do |lock|
  raise 'Another native build owns the lock' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  stdout, stderr, status = Open3.capture3(*command)
  File.write(File.join(output, 'compile.log'), stdout + stderr)
  raise stderr unless status.success?
  stdout, stderr, status = Open3.capture3(binary)
  File.write(File.join(output, 'runtime.log'), stdout + stderr)
  report = JSON.parse(stdout).merge(
    'scope' => 'Actual production completion identity policy only; not full ViewModel history, UI ordering or full gate',
    'command' => command, 'compile_exit' => 0, 'runtime_exit' => status.exitstatus,
    'seconds' => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3),
    'production_sha256' => Digest::SHA256.file(production).hexdigest,
    'fixture_sha256' => Digest::SHA256.file(fixture).hexdigest,
    'shared_xctest_service_used_or_restarted' => false)
  File.write(File.join(output, 'report.json'), JSON.pretty_generate(report) + "\n")
  File.write(File.join(output, 'report.md'), "# Blend If completion identity\n\n#{report['scope']}\n\n" +
    "| Active | Ending | May finish | Passed |\n|---|---|---|---|\n" +
    report.fetch('cases').map { |c| "| #{c['active']} | #{c['ending']} | #{c['may_finish']} | #{c['passed']} |" }.join("\n") + "\n")
  puts JSON.generate(report.reject { |key, _| key == 'cases' })
  exit(status.exitstatus) unless status.success? && report['passed']
end
