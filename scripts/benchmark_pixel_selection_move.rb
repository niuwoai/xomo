#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'open3'
require 'optparse'
require 'digest'

root = File.expand_path('..', __dir__)
options = { sizes: '512,1024,2048', iterations: 3, out: '/private/tmp/xomo-pixel-selection-move' }
OptionParser.new do |parser|
  parser.banner = 'Usage: ruby scripts/benchmark_pixel_selection_move.rb [options]'
  parser.on('--sizes LIST', 'Comma-separated bitmap edge lengths, 64..4096') { |value| options[:sizes] = value }
  parser.on('--iterations N', Integer, 'Alternating A/B iterations per case') { |value| options[:iterations] = value }
  parser.on('--out PREFIX', 'JSON and Markdown report prefix') { |value| options[:out] = value }
  parser.on('--compare-with PATH', 'Prior matching JSON report for measured before/after speedup') { |value| options[:before] = value }
  parser.on('-h', '--help', 'Show usage without compiling') { puts parser; exit }
end.parse!
abort 'iterations must be positive' unless options[:iterations].positive?
sizes = options[:sizes].split(',').map { |value| Integer(value, exception: false) }
abort 'sizes must be integers in 64..4096' unless sizes.any? && sizes.all? { |value| value && (64..4096).cover?(value) }

inputs = [
  'veilpic/ImageEditorFractionalPixelMove.swift',
  'veilpicTests/ImageEditorPixelMoveReference.swift',
  'scripts/benchmarks/pixel_selection_move.swift'
]
bounded = 'veilpic/ImageEditorPixelSelectionMovePixels.swift'
uses_bounds = File.exist?(File.join(root, bounded))
inputs << bounded if uses_bounds
directory = File.join(root, '.codex', 'PixelMoveBenchmark')
FileUtils.mkdir_p(directory)
executable = File.join(directory, 'pixel-selection-move')
compiler = ['xcrun', 'swiftc', '-O']
compiler += ['-D', 'XOMO_BOUNDED_PIXEL_MOVE'] if uses_bounds
compiler += inputs.map { |path| File.join(root, path) } + ['-o', executable]

File.open('/private/tmp/veilpic-build.lock', File::RDWR | File::CREAT, 0o600) do |lock|
  abort 'Another build owns the lock' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  output, status = Open3.capture2e(*compiler)
  abort "Benchmark compilation failed:\n#{output}" unless status.success?
  compile_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  output, status = Open3.capture2e(executable, options[:sizes], options[:iterations].to_s)
  abort "Benchmark verification failed:\n#{output}" unless status.success?
  report = JSON.parse(output)
  report['compile_seconds'] = compile_seconds
  report['compiler_command'] = compiler
  report['input_sha256'] = inputs.to_h { |path| [path, Digest::SHA256.file(File.join(root, path)).hexdigest] }
  report['generated_at'] = Time.now.strftime('%Y-%m-%d %H:%M:%S %z')
  if options[:before]
    previous = JSON.parse(File.read(options[:before]))
    abort 'Compiler optimization differs from the prior report' unless previous['compiler_optimization'] == report['compiler_optimization']
    report['compared_with'] = File.expand_path(options[:before])
    report.fetch('cases').each do |item|
      old = previous.fetch('cases').find do |candidate|
        %w[width height coverage iterations].all? { |key| candidate[key] == item[key] }
      end
      abort 'No matching scenario in the prior report' unless old && old['exact_pixels']
      item['before_current_median_ms'] = old.fetch('current_median_ms')
      item['measured_before_over_after'] = item['before_current_median_ms'] / item.fetch('current_median_ms')
    end
  end
  FileUtils.mkdir_p(File.dirname(options[:out]))
  File.write("#{options[:out]}.json", JSON.pretty_generate(report) + "\n")
  rows = report.fetch('cases').map do |item|
    before = item['before_current_median_ms'] ? format('%.3f', item['before_current_median_ms']) : 'not supplied'
    speedup = item['measured_before_over_after'] ? format('%.2fx', item['measured_before_over_after']) : 'not measured'
    format('| %d x %d | %s | %s | %.3f | %s | %s |', item['width'], item['height'],
           item['coverage'], before, item['current_median_ms'], speedup, item['exact_pixels'])
  end
  markdown = [
    '# Pixel selection move A/B benchmark', '',
    "Algorithm: #{report['current_algorithm']}; compiled with -O; #{options[:iterations]} alternating iterations.", '',
    '| Bitmap | Coverage | Before current ms | Current ms | Measured speedup | Exact pixels |',
    '|---|---|---:|---:|---:|---|', *rows, '',
    'This measures raw premultiplied RGBA clearing and compositing only. It excludes image conversion, selection-mask creation, UI latency, project history and peak process memory.',
    'The frozen reference is for byte equality, not a speed baseline: its sample array representation differs from the former production struct. Compare before/after current medians from matching reports for measured speedup.'
  ].join("\n") + "\n"
  File.write("#{options[:out]}.md", markdown)
  puts markdown
  puts "Reports: #{options[:out]}.{json,md}"
end
