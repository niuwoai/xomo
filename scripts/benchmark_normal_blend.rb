#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'open3'
require 'optparse'
require 'digest'

options = { sizes: '512,1024,2048', iterations: 3, out: '/private/tmp/xomo-normal-blend' }
OptionParser.new do |parser|
  parser.banner = 'Usage: ruby scripts/benchmark_normal_blend.rb [options]'
  parser.on('--sizes LIST', 'Comma-separated bitmap edge lengths, 64..4096') { |value| options[:sizes] = value }
  parser.on('--iterations N', Integer, 'Alternating equation-reference/kernel iterations') { |value| options[:iterations] = value }
  parser.on('--out PREFIX', 'JSON and Markdown report prefix') { |value| options[:out] = value }
  parser.on('-h', '--help', 'Show help without compiling') { puts parser; exit }
end.parse!
abort 'iterations must be positive' unless options[:iterations].positive?
sizes = options[:sizes].split(',').map { |value| Integer(value, exception: false) }
abort 'sizes must be integers in 64..4096' unless sizes.any? && sizes.all? { |value| value && (64..4096).cover?(value) }
root = File.expand_path('..', __dir__)
inputs = ['veilpic/ImageEditorNormalBlendKernel.swift', 'veilpicTests/ImageEditorNormalBlendReference.swift',
          'scripts/benchmarks/normal_blend.swift']
directory = File.join(root, '.codex', 'NormalBlendBenchmark')
FileUtils.mkdir_p(directory)
executable = File.join(directory, 'normal-blend')
compiler = ['xcrun', 'swiftc', '-O', *inputs.map { |path| File.join(root, path) }, '-o', executable]
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
  rows = report.fetch('cases').map do |item|
    format('| %d | %s | %.3f | %.3f | %s |', item['size'], item['case'],
           item['reference_median_ms'], item['kernel_median_ms'], item['exact_rgba'])
  end
  markdown = ['# Normal 合成公式与内核对照', '', "相同 -O、#{options[:iterations]} 次交替迭代；65536 种 alpha 对的七组不透明度逐字节一致。", '',
              '| 位图边长 | 场景 | 旧公式参考 ms | 当前内核 ms | RGBA 一致 |', '|---|---|---:|---:|---|', *rows, '',
              '参考保留旧 Normal 公式，但循环控制流不同，不是旧生产速度基线。只测 RGBA 内核，不含图像转换、模型更新、UI 或内存；实际前后收益另由同场景原生模型测量验证。'].join("\n") + "\n"
  FileUtils.mkdir_p(File.dirname(options[:out]))
  File.write("#{options[:out]}.json", JSON.pretty_generate(report) + "\n")
  File.write("#{options[:out]}.md", markdown)
  puts markdown
  puts "Reports: #{options[:out]}.{json,md}"
end
