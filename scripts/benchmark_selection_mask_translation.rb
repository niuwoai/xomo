#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'open3'
require 'optparse'
require 'digest'

options = { sizes: '512,1024,2048', iterations: 3, out: '/private/tmp/xomo-mask-translation' }
OptionParser.new do |parser|
  parser.banner = 'Usage: ruby scripts/benchmark_selection_mask_translation.rb [options]'
  parser.on('--sizes LIST', 'Comma-separated bitmap edge lengths, 64..4096') { |value| options[:sizes] = value }
  parser.on('--iterations N', Integer, 'Alternating scalar/row-copy iterations') { |value| options[:iterations] = value }
  parser.on('--out PREFIX', 'JSON and Markdown report prefix') { |value| options[:out] = value }
  parser.on('-h', '--help', 'Show help without compiling') { puts parser; exit }
end.parse!
abort 'iterations must be positive' unless options[:iterations].positive?
sizes = options[:sizes].split(',').map { |value| Integer(value, exception: false) }
abort 'sizes must be integers in 64..4096' unless sizes.any? && sizes.all? { |value| value && (64..4096).cover?(value) }
root = File.expand_path('..', __dir__)
inputs = ['veilpic/ImageEditorSelectionMaskTranslation.swift', 'veilpicTests/ImageEditorMaskTranslationReference.swift',
          'scripts/benchmarks/selection_mask_translation.swift']
directory = File.join(root, '.codex', 'MaskTranslationBenchmark')
FileUtils.mkdir_p(directory)
executable = File.join(directory, 'selection-mask-translation')
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
    format('| %d | %s | %.3f | %.3f | %s |', item['size'], item['coverage'],
           item['scalar_median_ms'], item['row_copy_median_ms'], item['exact_alpha'])
  end
  markdown = ['# 选区蒙版平移内核对照', '', "相同 -O、#{options[:iterations]} 次交替迭代；冻结 rc1705 逐像素公式与现行行复制使用同一 alpha 数据表示。", '',
              '| 位图边长 | 覆盖 | 逐像素 ms | 行复制 ms | alpha 逐字节一致 |', '|---|---|---:|---:|---|', *rows, '',
              '仅测单通道 alpha 平移，不包含光栅化、边界扫描、原生模型更新、UI 或内存峰值。完整模型另由 ImageEditorPixelMoveWorkflowProfileTests 验证。'].join("\n") + "\n"
  FileUtils.mkdir_p(File.dirname(options[:out]))
  File.write("#{options[:out]}.json", JSON.pretty_generate(report) + "\n")
  File.write("#{options[:out]}.md", markdown)
  puts markdown
  puts "Reports: #{options[:out]}.{json,md}"
end
