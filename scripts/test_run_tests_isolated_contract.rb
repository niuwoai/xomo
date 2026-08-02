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

puts 'run_tests_isolated contract: PASS'
