# frozen_string_literal: true

require 'open3'
require 'rbconfig'

ROOT = File.expand_path('..', __dir__)
RUNNER = File.join(ROOT, 'scripts', 'run_tests_isolated.rb')
ANCHOR = 'ImageEditorLayerRowBatchPropertyTests/layerStyleShadowSpreadMixedValueConvergesAcrossEditableSelection'
EXPECTED_NEXT = 'veilpicTests/ImageEditorLayerRowBatchPropertyTests/layerStyleShadowSpreadControlReusesMixedNumericStepper()'

def assert(condition, message)
  raise message unless condition
end

stdout, stderr, status = Open3.capture3(
  RbConfig.ruby,
  RUNNER,
  '--list',
  '--start-after',
  ANCHOR,
  chdir: ROOT
)
listed = stdout.lines.map(&:strip).reject(&:empty?)
assert(status.success?, "断点列举失败：#{stderr}")
assert(listed.first == EXPECTED_NEXT, "断点后的首项不正确：#{listed.first.inspect}")
assert(listed.none? { |identifier| identifier.include?(ANCHOR) }, '断点测试不应被重复列出')

_stdout, invalid_stderr, invalid_status = Open3.capture3(
  RbConfig.ruby,
  RUNNER,
  '--list',
  '--start-after',
  'MissingSuite/missingTest',
  chdir: ROOT
)
assert(!invalid_status.success?, '不存在的断点必须返回失败')
assert(invalid_stderr.include?('找不到 --start-after 指定的测试'), '不存在断点应返回可诊断错误')

help_stdout, help_stderr, help_status = Open3.capture3(
  RbConfig.ruby,
  RUNNER,
  '--help',
  chdir: ROOT
)
assert(help_status.success?, "读取运行器帮助失败：#{help_stderr}")
assert(help_stdout.include?('--test-timeout SECONDS'), '运行器必须暴露单测试超时选项')

runner_source = File.read(RUNNER, encoding: 'UTF-8')
assert(runner_source.include?('terminate_process_group(wait_thread) if wait_thread.alive?'), '中断或异常退出时必须回收整个 Xcode 进程组')
assert(runner_source.include?('XOMO_TEST_INFRASTRUCTURE_TIMEOUT'), '超时必须被归类为可重试的基础设施错误')

puts 'run_tests_isolated contract: PASS'
