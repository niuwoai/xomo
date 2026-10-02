#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'

class NormalBlendBenchmarkContractTest < Minitest::Test
  SCRIPT = File.expand_path('benchmark_normal_blend.rb', __dir__)

  def test_help_does_not_compile
    output, status = Open3.capture2e('ruby', SCRIPT, '--help')
    assert status.success?
    assert_includes output, '--out'
  end

  def test_invalid_size_is_rejected_before_compilation
    output, status = Open3.capture2e('ruby', SCRIPT, '--sizes', '512,broken')
    refute status.success?
    assert_includes output, 'sizes must be integers'
  end

  def test_out_of_budget_size_is_rejected_before_compilation
    output, status = Open3.capture2e('ruby', SCRIPT, '--sizes', '8192')
    refute status.success?
    assert_includes output, '64..4096'
  end

  def test_zero_iterations_are_rejected_before_compilation
    output, status = Open3.capture2e('ruby', SCRIPT, '--iterations', '0')
    refute status.success?
    assert_includes output, 'iterations must be positive'
  end
end
