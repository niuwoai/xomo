#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require_relative "release_contract"

options = {
  root: File.expand_path("..", __dir__),
  out: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/verify_release_contract.rb [options]"
  parser.on("--root PATH", "仓库根目录（默认当前仓库）") { |value| options[:root] = File.expand_path(value) }
  parser.on("--out DIR", "同时写入 report.json 和 report.md") { |value| options[:out] = File.expand_path(value) }
  parser.on("-h", "--help", "显示帮助") { puts parser; exit 0 }
end.parse!

result = XomoReleaseContract.collect(options[:root])
generated_at = Time.now.strftime("%Y-%m-%d %H:%M:%S %z")
result["generated_at"] = generated_at

if options[:out]
  FileUtils.mkdir_p(options[:out])
  File.write(File.join(options[:out], "report.json"), JSON.pretty_generate(result) + "\n")

  markdown = [
    "# Xomo 发布契约报告",
    "",
    "- 生成时间：#{generated_at}",
    "- 版本：`#{result["version"] || "未知"}`",
    "- 结论：#{result["passed"] ? "✅ 通过" : "❌ 失败"}",
    "",
    "| 检查项 | 结果 |",
    "|---|---|",
  ]
  result["checks"].each do |name, passed|
    markdown << "| #{name} | #{passed ? "通过" : "失败"} |"
  end
  markdown << ""
  File.write(File.join(options[:out], "report.md"), markdown.join("\n") + "\n")
end

puts JSON.pretty_generate(result)
exit(result["passed"] ? 0 : 1)
