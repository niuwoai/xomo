#!/usr/bin/env ruby
# frozen_string_literal: true
require 'json'
require 'digest'
require 'open3'

root = File.expand_path(ARGV.fetch(0))
version = ARGV.fetch(1)
names = %w[baseline mouse mouse-undone mouse-redone keyboard-observed mouse-restored
           fill fill-undone fill-redone reopened]
paths = names.to_h { |name| [name, File.join(root, name + '.xomoproject')] }
bytes = paths.transform_values { |path| File.binread(path) }
projects = bytes.transform_values { |data| JSON.parse(data) }
baseline = projects.fetch('baseline')
target_id = baseline.fetch('selectedLayerID')
targets = projects.transform_values do |project|
  project.fetch('layers').find { |layer| layer.fetch('id') == target_id } || raise('Missing target')
end
checks = {}
checks['current_version_and_format'] = projects.values.all? do |project|
  project.fetch('appVersion') == version && project.fetch('formatVersion') == 10
end
checks['canvas_dimensions'] = projects.values.all? { |project| project.fetch('canvasSize') == [1586, 992] }
checks['ordered_layer_ids_preserved'] = projects.values.all? do |project|
  project.fetch('layers').map { |layer| layer.fetch('id') } == baseline.fetch('layers').map { |layer| layer.fetch('id') }
end
checks['other_layers_unchanged'] = projects.values.map do |project|
  project.fetch('layers').reject { |layer| layer.fetch('id') == target_id }
end.uniq.size == 1
checks['target_bitmap_and_metadata_preserved'] = targets.values.map do |layer|
  layer.reject { |key, _| %w[opacity fillOpacity frame].include?(key) }
end.uniq.size == 1
checks['non_edit_document_fields_preserved'] = projects.values.map do |project|
  project.reject { |key, _| %w[layers historyTitles].include?(key) }
end.uniq.size == 1
checks['opacity_values_exact'] = targets.all? do |name, layer|
  layer.fetch('opacity') == (%w[baseline mouse-undone].include?(name) ? 1 : 0.5)
end
checks['fill_values_exact'] = targets.all? do |name, layer|
  layer.fetch('fillOpacity') == (%w[fill fill-redone reopened].include?(name) ? 0.5 : 1)
end
checks['ordinary_frames_unchanged'] = targets.reject { |name, _| name == 'keyboard-observed' }.values.all? do |layer|
  layer.fetch('frame') == [[0, 0], [1586, 992]]
end
checks['observed_keyboard_action_is_canvas_nudge'] = targets.fetch('keyboard-observed').fetch('frame') == [[1, 0], [1586, 992]]
checks['opacity_undo_complete_bytes_exact'] = bytes.fetch('baseline') == bytes.fetch('mouse-undone')
checks['opacity_redo_complete_bytes_exact'] = bytes.fetch('mouse') == bytes.fetch('mouse-redone')
checks['nudge_undo_complete_bytes_exact'] = bytes.fetch('mouse') == bytes.fetch('mouse-restored')
checks['fill_undo_complete_bytes_exact'] = bytes.fetch('mouse') == bytes.fetch('fill-undone')
checks['fill_redo_complete_bytes_exact'] = bytes.fetch('fill') == bytes.fetch('fill-redone')
checks['reopen_all_fields_except_history_exact'] = projects.fetch('fill-redone').reject { |key, _| key == 'historyTitles' } ==
  projects.fetch('reopened').reject { |key, _| key == 'historyTitles' }
[['baseline', 'mouse'], ['mouse', 'fill'], ['mouse', 'keyboard-observed'], ['fill-redone', 'reopened']].each do |before, after|
  old = projects.fetch(before).fetch('historyTitles')
  current = projects.fetch(after).fetch('historyTitles')
  checks[after + '_adds_one_history'] = current.size == old.size + 1 && current.first(old.size) == old
end
checks['observed_keyboard_history_is_layer_move'] = projects.fetch('keyboard-observed').fetch('historyTitles').last == '移动图层内容'

decode = lambda do |png|
  raise 'Not PNG' unless png.byteslice(0, 8) == "\x89PNG\r\n\x1A\n".b
  width, height = png.byteslice(16, 8).unpack('N2')
  rgba, error, status = Open3.capture3('magick', 'png:-', '-depth', '8', 'rgba:-', stdin_data: png)
  raise error[0, 300] unless status.success? && rgba.bytesize == width * height * 4
  { 'width' => width, 'height' => height, 'rgba' => rgba }
end
exports = %w[edited reopened].to_h { |name| [name, File.binread(File.join(root, name + '.png'))] }
decoded = exports.transform_values { |png| decode.call(png) }
checks['export_png_bytes_exact'] = exports.fetch('edited') == exports.fetch('reopened')
checks['export_rgba_exact'] = decoded.fetch('edited') == decoded.fetch('reopened')
checks['export_dimensions'] = decoded.values.all? { |im| [im.fetch('width'), im.fetch('height')] == [1586, 992] }
checks['export_has_nonuniform_visible_pixels'] = decoded.fetch('edited').fetch('rgba').bytes.each_slice(4).select { |p| p.last > 0 }.uniq.size > 1
files = paths.values + %w[edited.png reopened.png].map { |name| File.join(root, name) }
report = {
  'version' => version,
  'scope' => 'Completed mouse opacity/fill edits and separate Undo/Redo, save/reopen/export readback; not keyboard property, drag interruptions, cursors or full gate acceptance',
  'source_directory' => root, 'checks' => checks, 'passed' => checks.values.all?,
  'failed_checks' => checks.reject { |_, passed| passed }.keys,
  'keyboard_property_acceptance' => false,
  'keyboard_observation' => 'Right after track click moved selected layer one pixel; slider focus was not established',
  'drag_property_acceptance' => false,
  'files' => files.to_h { |path| [File.basename(path), { 'bytes' => File.size(path), 'sha256' => Digest::SHA256.file(path).hexdigest }] },
  'verifier' => { 'path' => File.expand_path(__FILE__), 'sha256' => Digest::SHA256.file(__FILE__).hexdigest }
}
json_path = File.join(root, 'mouse-property-readback.json')
markdown_path = File.join(root, 'mouse-property-readback.md')
raise 'Preserve existing reports' if File.exist?(json_path) || File.exist?(markdown_path)
File.write(json_path, JSON.pretty_generate(report) + "\n")
File.write(markdown_path, "# Mouse layer property readback\n\n#{report['scope']}\n\n" +
  "Keyboard property acceptance: false. Drag property acceptance: false.\n\n" +
  "| Check | Result |\n|---|---|\n" + checks.map { |name, passed| "| #{name} | #{passed} |" }.join("\n") + "\n")
puts JSON.generate(report.slice('passed', 'failed_checks', 'keyboard_property_acceptance', 'drag_property_acceptance'))
exit(report['passed'] ? 0 : 1)
