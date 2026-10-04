#!/usr/bin/env ruby
# frozen_string_literal: true
require 'json'
require 'digest'
require 'open3'

root = File.expand_path(ARGV.fetch(0))
version = ARGV.fetch(1)
names = %w[baseline black white white-undone black-undone black-redone white-redone reopened]
paths = names.to_h { |name| [name, File.join(root, name + '.xomoproject')] }
bytes = paths.transform_values { |path| File.binread(path) }
projects = bytes.transform_values { |data| JSON.parse(data) }
baseline = projects.fetch('baseline')
target_id = baseline.fetch('selectedLayerID')
targets = projects.transform_values do |project|
  project.fetch('layers').find { |layer| layer.fetch('id') == target_id } || raise('Missing selected layer')
end
black_value = 67.0 / 255
white_value = 194.0 / 255
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
checks['target_bitmap_and_other_properties_preserved'] = targets.values.map do |layer|
  layer.reject { |key, _| %w[blendIfSourceBlack blendIfSourceWhite].include?(key) }
end.uniq.size == 1
checks['other_document_fields_preserved'] = projects.values.map do |project|
  project.reject { |key, _| %w[layers historyTitles].include?(key) }
end.uniq.size == 1
checks['black_values_match_observed_mouse_result'] = targets.all? do |name, layer|
  layer.fetch('blendIfSourceBlack') == (%w[baseline black-undone].include?(name) ? 0 : black_value)
end
checks['white_values_match_observed_mouse_result'] = targets.all? do |name, layer|
  layer.fetch('blendIfSourceWhite') == (%w[white white-redone reopened].include?(name) ? white_value : 1)
end
checks['white_undo_restores_complete_black_project'] = bytes.fetch('white-undone') == bytes.fetch('black')
checks['black_undo_restores_complete_baseline'] = bytes.fetch('black-undone') == bytes.fetch('baseline')
checks['black_redo_restores_complete_black_project'] = bytes.fetch('black-redone') == bytes.fetch('black')
checks['white_redo_restores_complete_white_project'] = bytes.fetch('white-redone') == bytes.fetch('white')
checks['reopen_all_fields_except_added_history_exact'] = projects.fetch('reopened').reject { |key, _| key == 'historyTitles' } ==
  projects.fetch('white-redone').reject { |key, _| key == 'historyTitles' }
[['baseline', 'black'], ['black', 'white'], ['white-redone', 'reopened']].each do |before, after|
  old = projects.fetch(before).fetch('historyTitles')
  current = projects.fetch(after).fetch('historyTitles')
  checks[after + '_adds_one_history'] = current.size == old.size + 1 && current.first(old.size) == old
end

decode = lambda do |png|
  raise 'Not PNG' unless png.byteslice(0, 8) == "\x89PNG\r\n\x1A\n".b
  width, height = png.byteslice(16, 8).unpack('N2')
  rgba, error, status = Open3.capture3('magick', 'png:-', '-depth', '8', 'rgba:-', stdin_data: png)
  raise error[0, 300] unless status.success? && rgba.bytesize == width * height * 4
  { 'width' => width, 'height' => height, 'rgba' => rgba }
end
exports = %w[baseline edited reopened].to_h { |name| [name, File.binread(File.join(root, name + '.png'))] }
decoded = exports.transform_values { |png| decode.call(png) }
checks['edited_and_reopened_png_bytes_exact'] = exports.fetch('edited') == exports.fetch('reopened')
checks['edited_and_reopened_rgba_exact'] = decoded.fetch('edited') == decoded.fetch('reopened')
checks['all_export_dimensions'] = decoded.values.all? { |image| [image.fetch('width'), image.fetch('height')] == [1586, 992] }
original = decoded.fetch('baseline').fetch('rgba')
edited = decoded.fetch('edited').fetch('rgba')
changed_pixels = (0...edited.bytesize).step(4).count { |i| edited.byteslice(i, 4) != original.byteslice(i, 4) }
alpha_count = ->(rgba, visible) { (3...rgba.bytesize).step(4).count { |i| (rgba.getbyte(i) > 0) == visible } }
visible_before = alpha_count.call(original, true)
visible_after = alpha_count.call(edited, true)
checks['blend_if_changes_actual_export_pixels'] = changed_pixels > 0
checks['blend_if_reveals_transparency_and_retains_visible_content'] = visible_after > 0 && visible_after < visible_before
files = paths.values + %w[baseline.png edited.png reopened.png].map { |name| File.join(root, name) }
report = {
  'version' => version,
  'scope' => 'Physical source black/white edits, independent Undo/Redo, save/reopen and PNG readback; not delayed UI ordering, same-property session ownership, underlying controls or full gate',
  'source_directory' => root, 'checks' => checks, 'passed' => checks.values.all?,
  'failed_checks' => checks.reject { |_, passed| passed }.keys,
  'delayed_ui_ordering_accepted' => false, 'full_native_model_regression_executed' => false,
  'pixels' => { 'changed' => changed_pixels, 'visible_before' => visible_before, 'visible_after' => visible_after },
  'files' => files.to_h { |path| [File.basename(path), { 'bytes' => File.size(path), 'sha256' => Digest::SHA256.file(path).hexdigest }] },
  'verifier' => { 'path' => File.expand_path(__FILE__), 'sha256' => Digest::SHA256.file(__FILE__).hexdigest }
}
File.write(File.join(root, 'blend-if-readback.json'), JSON.pretty_generate(report) + "\n")
File.write(File.join(root, 'blend-if-readback.md'), "# Blend If 鼠标工作流读回\n\n#{report['scope']}\n\n" +
  "| Check | Passed |\n|---|---|\n" + checks.map { |name, passed| "| #{name} | #{passed} |" }.join("\n") + "\n")
puts JSON.pretty_generate(report)
exit(report.fetch('passed') ? 0 : 1)
