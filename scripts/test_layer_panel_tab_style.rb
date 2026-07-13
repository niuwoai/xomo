#!/usr/bin/env ruby

require "json"

root = File.expand_path("..", __dir__)
source_path = File.join(root, "veilpic", "ImageEditorLayerPanel.swift")
source = File.read(source_path, encoding: "UTF-8")

checks = {
  "uses_custom_tab_buttons" => source.include?("Button {") && source.include?("image-editor-layer-panel-tab-"),
  "does_not_use_system_segmented_picker" => !source.match?(/private var layerPanelTabs.*?pickerStyle\(\.segmented\)/m),
  "uses_native_label_with_explicit_light_foreground" =>
    source.include?("struct ImageEditorLayerPanelTabLabel: NSViewRepresentable") &&
      source.include?("label.textColor = isSelected ? selectedForegroundColor : foregroundColor"),
  "keeps_tabs_unfocusable" => source.match?(/private var layerPanelTabs.*?\.focusable\(false\)/m)
}

result = {
  test: "layer_panel_tab_style",
  passed: checks.values.all?,
  checks: checks
}

puts JSON.pretty_generate(result)
exit(result[:passed] ? 0 : 1)
