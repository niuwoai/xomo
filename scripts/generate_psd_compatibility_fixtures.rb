# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "zlib"

OUTPUT_DIR = File.expand_path("../veilpicTests/Fixtures/PSD", __dir__)
WIDTH = 4
HEIGHT = 4

def u16(value)
  [value & 0xffff].pack("n")
end

def i16(value)
  u16(value)
end

def u32(value)
  [value & 0xffff_ffff].pack("N")
end

def i32(value)
  u32(value)
end

def pascal(value, alignment: 4)
  bytes = value.encode("MacRoman", invalid: :replace, undef: :replace).bytes.first(255).pack("C*")
  output = [bytes.bytesize].pack("C") + bytes
  output << "\0" until (output.bytesize % alignment).zero?
  output
end

def tagged_block(key, payload)
  output = "8BIM" + key + u32(payload.bytesize) + payload
  output << "\0" if payload.bytesize.odd?
  output
end

def unicode_name(value)
  utf16 = value.encode("UTF-16BE").b
  tagged_block("luni", u32(utf16.bytesize / 2) + utf16)
end

def f64(value)
  [value].pack("G")
end

def unicode_string(value)
  utf16 = value.encode("UTF-16BE").b
  u32(utf16.bytesize / 2) + utf16
end

def descriptor_key(value)
  bytes = value.b
  if bytes.bytesize == 4
    u32(0) + bytes
  else
    u32(bytes.bytesize) + bytes
  end
end

def descriptor_block(name:, class_id:, items: [])
  u32(16) + unicode_string(name) + descriptor_key(class_id) + u32(items.length) + items.join
end

def descriptor_item(key:, type:, payload:)
  descriptor_key(key) + type + payload
end

def engine_string(value)
  "(" + "\xFE\xFF".b + value.encode("UTF-16BE").b + ")"
end

def editable_text_engine_data
  text = "Hello Xomo"
  output = +"<<\n/EngineDict <<\n/Editor <<\n/Text "
  output << engine_string(text)
  output << "\n>>\n/StyleRun <<\n/RunLengthArray [ #{text.length} ]\n"
  output << "/RunArray [ << /StyleSheet << /StyleSheetData << /Font 0 /FontSize 24.0 "
  output << "/FauxBold true /FauxItalic true /Underline true /Strikethrough true "
  output << "/Tracking 100.0 /Leading 6.0 /LeftIndent 1.5 /RightIndent 2.5 /FirstLineIndent -3.0 "
  output << "/FillColor << /Type 1 /Values [ 0.2 0.4 0.8 1.0 ] >> >> >> >> ]\n>>\n"
  output << "/ParagraphRun << /RunLengthArray [ #{text.length} ] "
  output << "/RunArray [ << /ParagraphSheet << /Properties << /Justification 2 >> >> >> ] >>\n"
  output << "/Rendered << /Shapes << /Children [ << /Cookie << /Photoshop << /ShapeType 1 >> >> >> ] >> >>\n"
  output << ">>\n/ResourceDict << /FontSet [ << /Name "
  output << engine_string("Helvetica")
  output << " /FontFamily " << engine_string("Helvetica") << " /FontStyle " << engine_string("Regular") << " >> ] >>\n>>"
  output
end

def editable_text_tysh
  text_data = editable_text_engine_data
  descriptor = descriptor_block(
    name: "",
    class_id: "TxLr",
    items: [
      descriptor_item(key: "Txt ", type: "TEXT", payload: unicode_string("Hello Xomo")),
      descriptor_item(key: "EngineData", type: "tdta", payload: u32(text_data.bytesize) + text_data)
    ]
  )
  warp = descriptor_block(name: "", class_id: "warp", items: [])
    u16(1) + ([1.0, 0.0, 0.0, 1.0, 0.0, 0.0].map { |value| f64(value) }.join) +
    u16(50) + descriptor + u16(1) + warp + [0.0, 0.0, 2.0, 3.0].map { |value| f64(value) }.join
end

def layer_mask_data(enabled: true, linked: true)
  flags = 0
  flags |= 1 if linked
  flags |= 2 unless enabled
  u32(20) + i32(0) + i32(0) + i32(HEIGHT) + i32(WIDTH) + [0, flags].pack("C*") + u16(0)
end

def layer_extra(name:, blocks:, mask: nil)
  (mask || u32(0)) + u32(0) + pascal(name) + unicode_name(name) + blocks.join
end

def layer_record(name:, channels:, blend: "norm", opacity: 255, clipping: 0, flags: 0, blocks: [], mask: nil, frame: [0, 0, HEIGHT, WIDTH])
  top, left, bottom, right = frame
  extra = layer_extra(name: name, blocks: blocks, mask: mask)
  output = i32(top) + i32(left) + i32(bottom) + i32(right) + u16(channels.length)
  channels.each do |identifier, bytes|
    output << i16(identifier) << u32(bytes.bytesize)
  end
  output + "8BIM" + blend + [opacity, clipping, flags, 0].pack("C*") + u32(extra.bytesize) + extra
end

def predict(bytes, width: WIDTH, height: HEIGHT)
  output = bytes.bytes
  height.times do |row|
    row_start = row * width
    (width - 1).downto(1) do |column|
      index = row_start + column
      output[index] = (output[index] - output[index - 1]) & 0xff
    end
  end
  output.pack("C*")
end

def zip_channel(bytes, prediction: false)
  payload = prediction ? predict(bytes) : bytes
  u16(prediction ? 3 : 2) + Zlib::Deflate.deflate(payload)
end

def raw_channel(bytes)
  u16(0) + bytes
end

def header(channels: 4, width: WIDTH, height: HEIGHT, depth: 8, color_mode: 3)
  "8BPS" + u16(1) + ("\0" * 6) + u16(channels) + u32(height) + u32(width) + u16(depth) + u16(color_mode)
end

def image_resources(include_icc: false)
  return u32(0) unless include_icc

  name = "\0\0"
  profile = "TEST"
  block = "8BIM" + u16(1039) + name + u32(profile.bytesize) + profile
  u32(block.bytesize) + block
end

def composite_zip(red:, green:, blue:, alpha:)
  u16(2) + Zlib::Deflate.deflate(red + green + blue + alpha)
end

def psd(layer_payload:, composite:, include_icc: false)
  header + u32(0) + image_resources(include_icc: include_icc) + layer_payload + composite
end

def group_mask_fixture
  red = (0...16).map { |index| 20 + index }.pack("C*")
  green = (0...16).map { |index| 80 + index }.pack("C*")
  blue = (0...16).map { |index| 140 + index }.pack("C*")
  alpha = ([255] * 16).pack("C*")
  mask = [255, 255, 0, 0, 255, 255, 0, 0, 0, 0, 255, 255, 0, 0, 255, 255].pack("C*")
  child_channels = {
    -1 => zip_channel(alpha, prediction: true),
    0 => zip_channel(red, prediction: true),
    1 => zip_channel(green, prediction: true),
    2 => zip_channel(blue, prediction: true),
    -2 => zip_channel(mask, prediction: true)
  }
  group_blocks = [
    tagged_block("iOpa", [220, 0, 0, 0].pack("C*")),
    tagged_block("lspf", u32(1)),
    tagged_block("lsct", u32(1) + "8BIM" + "pass")
  ]
  child_blocks = [
    tagged_block("iOpa", [128, 0, 0, 0].pack("C*")),
    tagged_block("lspf", u32(6))
  ]
  divider_blocks = [tagged_block("lsct", u32(3))]
  records = +""
  records << layer_record(name: "UI Group", channels: {}, blend: "pass", blocks: group_blocks)
  records << layer_record(
    name: "Masked Card",
    channels: child_channels,
    blend: "lLit",
    opacity: 200,
    flags: 1,
    blocks: child_blocks,
    mask: layer_mask_data
  )
  records << layer_record(name: "</Layer group>", channels: {}, flags: 2, blocks: divider_blocks, frame: [0, 0, 0, 0])
  channel_data = child_channels.values.join
  layer_info = i16(3) + records + channel_data
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  layer_payload = u32(layer_and_mask.bytesize) + layer_and_mask
  psd(
    layer_payload: layer_payload,
    composite: composite_zip(red: red, green: green, blue: blue, alpha: alpha),
    include_icc: true
  )
end

def composite_only_fixture
  red = ([200] * 16).pack("C*")
  green = ([120] * 16).pack("C*")
  blue = ([40] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  psd(
    layer_payload: u32(0),
    composite: composite_zip(red: red, green: green, blue: blue, alpha: alpha)
  )
end

def unsupported_features_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  blocks = %w[TySh vmsk SoLd lfx2 SoCo].map { |key| tagged_block(key, "") }
  record = layer_record(name: "Complex Design Layer", channels: channels, blend: "zzzz", blocks: blocks)
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def editable_text_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Editable Greeting",
    channels: channels,
    blocks: [tagged_block("TySh", editable_text_tysh)],
    frame: [0, 0, HEIGHT, WIDTH]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

FileUtils.mkdir_p(OUTPUT_DIR)
fixtures = {
  "zip-group-mask.psd" => group_mask_fixture,
  "zip-composite.psd" => composite_only_fixture,
  "unsupported-features.psd" => unsupported_features_fixture,
  "editable-text.psd" => editable_text_fixture
}
fixtures.each do |name, bytes|
  File.binwrite(File.join(OUTPUT_DIR, name), bytes)
end

expectations = {
  "zip-group-mask.psd" => %w[zip zip_prediction group raster_mask fill_opacity layer_locks],
  "zip-composite.psd" => %w[zip flattened_composite],
  "unsupported-features.psd" => %w[compatibility_report unsupported_semantic_features],
  "editable-text.psd" => %w[editable_text font_size color alignment]
}
manifest = {
  generator: "scripts/generate_psd_compatibility_fixtures.rb",
  specification: "Adobe Photoshop File Formats Specification",
  fixtures: fixtures.map do |name, bytes|
    { file: name, sha256: Digest::SHA256.hexdigest(bytes), expected: expectations.fetch(name) }
  end
}
File.write(File.join(OUTPUT_DIR, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
