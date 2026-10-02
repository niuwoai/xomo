#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# verify_readme.rb — 校验仓库根 README.md 的链接、锚点与关键数字声明
#
# 用法：
#   ruby scripts/verify_readme.rb
#
# 覆盖四类断言：
#   1. README 里所有相对链接与图片路径都存在，且已被 git 跟踪
#      （未跟踪的文件在公开仓库上会 404）。
#   2. 页内锚点按 GitHub 的分词规则（小写、去标点、空格转连字符、不折叠连续空格）
#      能匹配到实际标题。
#   3. README 中的关键数字与仓库当前事实一致：自动化工具数、组件家族/主题数、
#      源码与测试规模、changelog 版本数、部署目标、CLI 的 swift-tools 版本、
#      最近 30 天提交数。
#   4. README 里出现的命令真的可用：`xomo <subcommand>` 必须是 main.swift 顶层
#      分支里的子命令，`xomo call <tool>` 必须在自动化注册表里存在。
#
# 该脚本是「README 与仓库同步」的快照守卫：改造产品后如果数字变了，
# 要么更新 README，要么在这里明确改口径，不要让两者静默漂移。
# =============================================================================

require "open3"

ROOT     = File.expand_path("..", __dir__)
README   = File.join(ROOT, "README.md")
failures = []
CHECKS   = [0]

def check(failures, description)
  CHECKS[0] += 1
  result = yield
  return if result == true

  failures << "#{description}：#{result}"
end

def tracked?(path)
  _out, status = Open3.capture2e("git", "-C", ROOT, "ls-files", "--error-unmatch", path)
  status.success?
end

def relative_files(readme)
  targets = readme.scan(/\]\(([^)]+)\)/).flatten + readme.scan(/(?:src|href)="([^"]+)"/).flatten
  targets
    .reject { |t| t.match?(%r{\Ahttps?://}) || t.start_with?("#", "mailto:") }
    .map { |t| t.split("#").first }
    .reject { |t| t.nil? || t.empty? }
    .uniq
end

def github_slug(heading)
  heading.downcase.gsub(/[^a-z0-9 _-]/, "").gsub(" ", "-")
end

def count_leading_enum_cases(source, enum_name)
  block = source[/enum #{enum_name}\b.*?\n\}/m]
  return nil unless block

  count = 0
  block.each_line do |line|
    if line.match?(/^    case [a-zA-Z]/)
      count += 1
    elsif count.positive?
      break
    end
  end
  count
end

readme = File.read(README)
changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
registry = File.read(File.join(ROOT, "veilpic/XomoAutomationRegistry.swift"))

# --- 1. 相对链接与图片路径 -----------------------------------------------------
files = relative_files(readme)
missing = files.reject { |f| File.exist?(File.join(ROOT, f)) }
untracked = files.reject { |f| tracked?(f) }

check(failures, "相对引用缺失（#{files.size} 个引用）") { missing.empty? || missing.join(", ") }
check(failures, "相对引用未被 git 跟踪（公开后会 404）") { untracked.empty? || untracked.join(", ") }
check(failures, "相对引用数量异常") { files.size >= 10 || "只找到 #{files.size} 个相对引用" }

# --- 2. 页内锚点 --------------------------------------------------------------
anchors = readme.scan(/\]\(#([^)]+)\)/).flatten
slugs = readme.scan(/^#+\s+(.*)$/).flatten.map { |h| github_slug(h) }
bad_anchors = anchors.reject { |a| slugs.include?(a) }

check(failures, "页内锚点无法匹配标题") { bad_anchors.empty? || bad_anchors.join(", ") }

# --- 3. 关键数字声明 ----------------------------------------------------------
# 注意：工具名里可能出现驼峰（如 xomo.text.fitBox），字符集必须覆盖大小写，
# 否则会漏数并让 README 与注册表「一起错」。
tool_names = registry.scan(/tool\("(xomo\.[^"]+)"/).flatten.uniq
handler_names = registry.scan(/case "(xomo\.[^"]+)"/).flatten.uniq
declared_tools = readme[/(\d+) automation tools\b/, 1]&.to_i
check(failures, "自动化工具数不一致") do
  declared_tools == tool_names.size || "README 写 #{declared_tools}，注册表实测 #{tool_names.size}"
end
# 同一个数字在徽章、hero、对照表、Extend it 里各出现一次，必须一起改。
check(failures, "工具数在 README 内自相矛盾") do
  mentions = readme.scan(/(\d+)\*{0,2} automation tools\b/).flatten.map(&:to_i)
  mentions += readme.scan(/automation%20tools-(\d+)/).flatten.map(&:to_i)
  mentions += readme.scan(/All \*\*(\d+)\*\* tools live there/).flatten.map(&:to_i)
  mentions.uniq == [tool_names.size] || "README 里出现过 #{mentions.uniq.join(", ")}，注册表是 #{tool_names.size}"
end
check(failures, "端点文件权限声明失效") do
  File.read(File.join(ROOT, "veilpic/XomoAutomationServer.swift")).include?(".posixPermissions: 0o600") ||
    "XomoAutomationServer.swift 里找不到 .posixPermissions: 0o600"
end
check(failures, "工具声明与执行分支不匹配") do
  only_declared = tool_names - handler_names
  only_handled = handler_names - tool_names
  (only_declared.empty? && only_handled.empty?) ||
    "只在 schema 里：#{only_declared.join(", ")}；只在 switch 里：#{only_handled.join(", ")}"
end

check(failures, "README 调用了注册表里没有的工具") do
  called = readme.scan(/xomo call (xomo\.[A-Za-z_.]+)/).flatten.uniq
  unknown = called - tool_names
  unknown.empty? || unknown.join(", ")
end

cli_main = File.read(File.join(ROOT, "xomo-cli/Sources/XomoCLI/main.swift"))
cli_switch = cli_main[/switch command \{(.*?)^        \}/m, 1]
raise "verify_readme：无法解析 xomo-cli 顶层命令分支" if cli_switch.nil?

subcommands = cli_switch.scan(/case "([a-z][a-z-]*)"/).flatten.uniq
check(failures, "README 使用了不存在的 xomo 子命令") do
  used = readme.scan(/(?<![\w.\/-])xomo ([a-z][a-z-]*)/).flatten.uniq
  unknown = used - subcommands
  unknown.empty? || "#{unknown.join(", ")}（可用：#{subcommands.sort.join(", ")}）"
end

app_sources = Dir.glob(File.join(ROOT, "veilpic/**/*.swift"))
app_lines = app_sources.sum { |f| File.foreach(f).count }
test_sources = Dir.glob(File.join(ROOT, "veilpicTests/**/*.swift")) +
               Dir.glob(File.join(ROOT, "veilpicUITests/**/*.swift"))
test_lines = test_sources.sum { |f| File.foreach(f).count }

declared_app = readme[/It is genuinely native\*\* \| (\d+) Swift sources, ~(\d+)k lines/, 1]&.to_i
declared_app_k = readme[/It is genuinely native\*\* \| (\d+) Swift sources, ~(\d+)k lines/, 2]&.to_i
check(failures, "App 源文件数不一致") do
  declared_app == app_sources.size || "README 写 #{declared_app}，实测 #{app_sources.size}"
end
check(failures, "App 代码行数量级不一致") do
  (app_lines / 1000).floor == declared_app_k || "README 写 ~#{declared_app_k}k，实测 #{(app_lines / 1000).floor}k"
end

declared_tests = readme[/(\d+) test sources, ~(\d+)k lines/, 1]&.to_i
declared_tests_k = readme[/(\d+) test sources, ~(\d+)k lines/, 2]&.to_i
check(failures, "测试源文件数不一致") do
  declared_tests == test_sources.size || "README 写 #{declared_tests}，实测 #{test_sources.size}"
end
check(failures, "测试行数量级不一致") do
  (test_lines / 1000).floor == declared_tests_k || "README 写 ~#{declared_tests_k}k，实测 #{(test_lines / 1000).floor}k"
end

component_families = count_leading_enum_cases(
  File.read(File.join(ROOT, "veilpic/XomoComponentInsertion.swift")), "XomoComponentKind"
)
theme_packs = count_leading_enum_cases(File.read(File.join(ROOT, "veilpic/XomoComponentTheme.swift")), "XomoComponentTheme")
declared_families = readme[/(\d+) editable UI component families across (\d+) theme packs/, 1]&.to_i
declared_themes = readme[/(\d+) editable UI component families across (\d+) theme packs/, 2]&.to_i
check(failures, "UI 组件家族数不一致") do
  declared_families == component_families || "README 写 #{declared_families}，实测 #{component_families}"
end
check(failures, "主题包数不一致") do
  declared_themes == theme_packs || "README 写 #{declared_themes}，实测 #{theme_packs}"
end

declared_versions = readme[/([\d,]+)\+? logged releases/, 1]&.delete(",")&.to_i
actual_versions = changelog.scan(/^## /).size
check(failures, "changelog 版本条目数不一致") do
  actual_versions >= declared_versions || "README 声称 #{declared_versions}+，实测 #{actual_versions}"
end

declared_changes = readme[/([\d,]+)\+ documented changes/, 1]&.delete(",")&.to_i
actual_changes = changelog.scan(/^- /).size
check(failures, "changelog 变更条数不一致") do
  actual_changes >= declared_changes || "README 声称 #{declared_changes}+，实测 #{actual_changes}"
end

declared_commits = readme[/(\d+) commits in the last 30 days/, 1]&.to_i
actual_commits, = Open3.capture2("git", "-C", ROOT, "rev-list", "--count", "--since=30 days ago", "HEAD")
actual_commits = actual_commits.strip.to_i
check(failures, "近 30 天提交数声明已过期") do
  actual_commits >= declared_commits || "README 声称 #{declared_commits}，实测 #{actual_commits}"
end

deployment_target = File.read(File.join(ROOT, "veilpic.xcodeproj/project.pbxproj"))[/MACOSX_DEPLOYMENT_TARGET = ([\d.]+)/, 1]
declared_macos = readme[/macOS (\d+) Ventura or newer/, 1]
check(failures, "最低系统版本不一致") do
  declared_macos == deployment_target.to_s.split(".").first ||
    "README 写 macOS #{declared_macos}，工程设置 #{deployment_target}"
end

cli_tools_version = File.read(File.join(ROOT, "xomo-cli/Package.swift"))[/swift-tools-version: ([\d.]+)/, 1]
declared_tools_version = readme[/swift-tools-version ([\d.]+)/, 1]
check(failures, "CLI swift-tools 版本不一致") do
  declared_tools_version == cli_tools_version ||
    "README 写 #{declared_tools_version}，Package.swift 写 #{cli_tools_version}"
end

# --- 汇总 ---------------------------------------------------------------------
puts "verify_readme: #{CHECKS[0]} 项断言，#{failures.size} 项失败"
failures.each { |f| puts "  FAIL #{f}" }
if failures.empty?
  puts "README 与仓库当前事实一致"
  exit 0
end
exit 1
