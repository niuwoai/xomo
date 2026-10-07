#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'minitest/autorun'

class ProductOverviewArchiveTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ARCHIVES = Dir.glob(File.join(ROOT, 'docs/product-overview/history-*.md')).sort.freeze
  HISTORY_SHA256 = '5efa1684b561cb8308a62c8e3c084c1c34b4a9f893e60a0a568d9f627a530883'
  FOOTER = "<!-- END ARCHIVED HISTORY -->\n"

  def test_archived_history_is_lossless_after_relative_link_relocation
    assert_equal 3, ARCHIVES.length
    restored = ARCHIVES.map do |path|
      content = File.readlines(path).drop(4).join
      assert content.end_with?(FOOTER), path
      content.delete_suffix(FOOTER).gsub('](../reviews/', '](docs/reviews/')
    end.join
    assert_equal HISTORY_SHA256, Digest::SHA256.hexdigest(restored)
  end

  def test_archives_obey_file_limit_and_have_working_local_links
    ARCHIVES.each do |path|
      assert_operator File.readlines(path).length, :<=, 3_000, path
      File.read(path).scan(/\]\(([^)]+)\)/).flatten.each do |target|
        assert File.file?(File.expand_path(target, File.dirname(path))), target
      end
    end
  end

  def test_current_overview_remains_versioned_and_bounded
    overview = File.read(File.join(ROOT, 'product-overview.md'))
    version = File.read(File.join(ROOT, 'veilpic/AppModels.swift'))[/static let current = "([^"]+)"/, 1]
    refute_nil version
    assert_includes overview, "当前版本：v#{version}"
    assert_operator overview.lines.length, :<=, 3_000
    assert_includes overview, '## 核心工作流'
    assert_includes overview, '## 当前实现状态'
    assert_includes overview, '当前安装版仍为 rc1729'
    assert_includes overview, '下一门槛为 rc1760'
  end
end
