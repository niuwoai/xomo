#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# run_tests_isolated.rb — 逐个测试独立进程运行 veilpicTests，规避并行踩踏
#
# 背景（为什么需要它）：
#   veilpicTests 里大量像素/渲染类测试依赖 AppKit 进程级的绘图 / NSColor /
#   命名(calibrated)色彩空间机制。Swift Testing 默认并行执行，多个渲染测试
#   同时访问这块进程级共享状态时会互相踩踏：CoreGraphics 狂刷
#   "Bad colorspace name NSNamedColorSpace"，渲染结果错乱，于是"单独跑能过、
#   整套并行就红"。实测 @Suite(.serialized) 在当前 Xcode 环境无法真正串行化
#   Swift Testing 的执行，-parallel-testing-enabled NO 也只管 XCTest 的多进程
#   worker，管不到 Swift Testing 的进程内并行。
#
#   已验证：把每个测试放进各自独立的 xcodebuild 进程里运行（进程之间内存隔离，
#   不共享那块全局绘图状态），整套即可稳定全绿。本脚本就是做这件事，并输出
#   JSON + Markdown 两份报告。
#
# 用法：
#   ruby scripts/run_tests_isolated.rb                 # 串行，最稳（默认）
#   ruby scripts/run_tests_isolated.rb --jobs 4        # 4 个独立进程并行（更快）
#   ruby scripts/run_tests_isolated.rb --filter Filter # 只跑名字含 Filter 的测试
#   ruby scripts/run_tests_isolated.rb --skip-build    # 复用上次 build-for-testing 产物
#
# 说明：
#   - 每个测试跑一次独立 xcodebuild，慢，但结果确定、可全绿，适合 CI。
#   - --jobs N 用多个"各跑一个测试"的独立进程并行；每个进程仍只跑一个测试，
#     不引入进程内并发，因此依然安全，只是同时占用多个 App Host / GPU。
# =============================================================================

require 'json'
require 'optparse'
require 'fileutils'
require 'open3'
require 'thread'

PROJECT     = 'veilpic.xcodeproj'
SCHEME      = 'veilpic'
DESTINATION = 'platform=macOS'
TEST_TARGET = 'veilpicTests'
TESTS_DIR   = File.join(__dir__, '..', TEST_TARGET)

options = {
  jobs: 1,
  filter: nil,
  out_dir: File.join(__dir__, '..', 'test-reports'),
  skip_build: false,
  stop_on_first_failure: false,
}

OptionParser.new do |o|
  o.banner = 'Usage: ruby scripts/run_tests_isolated.rb [options]'
  o.on('--jobs N', Integer, '并行独立进程数（默认 1 = 串行，最稳）') { |v| options[:jobs] = [v, 1].max }
  o.on('--filter SUBSTR', '只运行标识符包含该子串的测试') { |v| options[:filter] = v }
  o.on('--out DIR', '报告输出目录（默认 test-reports/）') { |v| options[:out_dir] = v }
  o.on('--skip-build', '跳过 build-for-testing，复用已有产物') { options[:skip_build] = true }
  o.on('--fail-fast', '出现第一个失败即停止') { options[:stop_on_first_failure] = true }
  o.on('-h', '--help', '显示帮助') { puts o; exit 0 }
end.parse!

REPO_ROOT = File.expand_path(File.join(__dir__, '..'))
Dir.chdir(REPO_ROOT)

# -----------------------------------------------------------------------------
# 1. 解析测试标识符：veilpicTests/<Suite>/<testMethod>
# -----------------------------------------------------------------------------
def enumerate_tests(dir)
  tests = []
  Dir.glob(File.join(dir, '*.swift')).sort.each do |file|
    current_suite = nil
    pending_test = false
    File.foreach(file, encoding: 'UTF-8') do |line|
      if (m = line.match(/\bstruct\s+([A-Za-z_]\w*Tests)\b/))
        current_suite = m[1]
        next
      end
      pending_test = true if line =~ /@Test\b/
      if pending_test && (m = line.match(/\bfunc\s+([A-Za-z_]\w*)\s*\(/))
        tests << { suite: current_suite, method: m[1], file: File.basename(file) } if current_suite
        pending_test = false
      end
    end
  end
  tests
end

# -----------------------------------------------------------------------------
# 2. 运行辅助
# -----------------------------------------------------------------------------
def base_xcodebuild_args
  [
    'xcodebuild',
    '-project', PROJECT,
    '-scheme', SCHEME,
    '-destination', DESTINATION,
  ]
end

def build_for_testing
  puts '==> build-for-testing …'
  args = base_xcodebuild_args + ['build-for-testing']
  out, status = Open3.capture2e(*args)
  unless status.success?
    warn out.lines.last(40).join
    abort '构建失败（build-for-testing），请先修复编译错误。'
  end
  puts '==> 构建完成。'
end

# 运行单个测试；返回 result Hash
def run_one(test, logs_dir)
  identifier = "#{TEST_TARGET}/#{test[:suite]}/#{test[:method]}"
  args = base_xcodebuild_args + [
    'test-without-building',
    "-only-testing:#{identifier}",
  ]
  started = Time.now
  out, status = Open3.capture2e(*args)
  duration = Time.now - started

  log_path = File.join(logs_dir, "#{test[:suite]}.#{test[:method]}.log")
  File.write(log_path, out)

  passed = status.success?
  issues = out.scan(/recorded an issue at .*/).map(&:strip).uniq

  {
    suite: test[:suite],
    method: test[:method],
    identifier: identifier,
    file: test[:file],
    passed: passed,
    duration: duration.round(3),
    issues: issues,
    log: File.basename(log_path),
  }
end

# -----------------------------------------------------------------------------
# 3. 主流程
# -----------------------------------------------------------------------------
tests = enumerate_tests(TESTS_DIR)
tests.select! { |t| "#{t[:suite]}/#{t[:method]}".include?(options[:filter]) } if options[:filter]

if tests.empty?
  abort '没有匹配到任何测试。请检查 --filter 或测试源码。'
end

FileUtils.mkdir_p(options[:out_dir])
logs_dir = File.join(options[:out_dir], 'logs')
FileUtils.mkdir_p(logs_dir)

puts "==> 共 #{tests.size} 个测试，jobs=#{options[:jobs]}，输出目录：#{options[:out_dir]}"
build_for_testing unless options[:skip_build]

results = []
results_mutex = Mutex.new
queue = Queue.new
tests.each_with_index { |t, i| queue << [i, t] }
stop = false
done_count = 0

workers = Array.new(options[:jobs]) do
  Thread.new do
    loop do
      item = begin
        queue.pop(true)
      rescue ThreadError
        break
      end
      break if stop
      idx, test = item
      res = run_one(test, logs_dir)
      results_mutex.synchronize do
        results << res
        done_count += 1
        mark = res[:passed] ? '✔' : '✘'
        printf("[%3d/%3d] %s %s (%.1fs)\n", done_count, tests.size, mark, res[:identifier], res[:duration])
        if !res[:passed] && options[:stop_on_first_failure]
          stop = true
        end
      end
    end
  end
end
workers.each(&:join)

# -----------------------------------------------------------------------------
# 4. 报告
# -----------------------------------------------------------------------------
results.sort_by! { |r| [r[:suite].to_s, r[:method].to_s] }
passed = results.count { |r| r[:passed] }
failed = results.size - passed
generated_at = Time.now.strftime('%Y-%m-%d %H:%M:%S %z')

summary = {
  generated_at: generated_at,
  total: results.size,
  passed: passed,
  failed: failed,
  jobs: options[:jobs],
  results: results,
}

json_path = File.join(options[:out_dir], 'report.json')
File.write(json_path, JSON.pretty_generate(summary))

md = +""
md << "# veilpicTests 独立进程测试报告\n\n"
md << "- 生成时间：#{generated_at}\n"
md << "- 总数：**#{results.size}**，通过：**#{passed}**，失败：**#{failed}**\n"
md << "- 并行度（jobs）：#{options[:jobs]}\n\n"

if failed.zero?
  md << "✅ 全部通过。\n\n"
else
  md << "## ❌ 失败测试（#{failed}）\n\n"
  md << "| 套件 | 测试 | 耗时(s) | 首个断言 |\n|---|---|---|---|\n"
  results.reject { |r| r[:passed] }.each do |r|
    first_issue = (r[:issues].first || '').gsub('|', '\\|')[0, 160]
    md << "| #{r[:suite]} | #{r[:method]} | #{r[:duration]} | #{first_issue} |\n"
  end
  md << "\n"
end

by_suite = results.group_by { |r| r[:suite] }
md << "## 按套件汇总\n\n"
md << "| 套件 | 通过/总数 |\n|---|---|\n"
by_suite.keys.sort.each do |suite|
  rs = by_suite[suite]
  md << "| #{suite} | #{rs.count { |r| r[:passed] }}/#{rs.size} |\n"
end
md << "\n"

md_path = File.join(options[:out_dir], 'report.md')
File.write(md_path, md)

puts "\n==> 报告已生成："
puts "    #{json_path}"
puts "    #{md_path}"
puts "==> 结果：通过 #{passed} / #{results.size}，失败 #{failed}"
exit(failed.zero? ? 0 : 1)
