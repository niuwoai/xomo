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

def fixed8_24(value)
  i32((value * (1 << 24)).round)
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
  u32(16) + descriptor_body(name: name, class_id: class_id, items: items)
end

def descriptor_body(name:, class_id:, items: [])
  unicode_string(name) + descriptor_key(class_id) + u32(items.length) + items.join
end

def descriptor_item(key:, type:, payload:)
  descriptor_key(key) + type + payload
end

def descriptor_enum_payload(enum_type:, value:)
  descriptor_key(enum_type) + descriptor_key(value)
end

def engine_string(value)
  "(" + "\xFE\xFF".b + value.encode("UTF-16BE").b + ")"
end

def vector_mask_payload(flags: 0, include_hole: false)
  record = ->(selector, points) {
    u16(selector) + points.map { |vertical, horizontal| fixed8_24(vertical) + fixed8_24(horizontal) }.join
  }
  fill_rule = u16(6) + ("\0" * 24)
  subpath = lambda do |points|
    # A vector path length record is 26 bytes: selector (2), knot count (2),
    # and 22 reserved bytes.
    length = u16(0) + u16(points.length) + ("\0" * 22)
    knots = points.each_with_index.map { |point, index| record.call(index.zero? ? 1 : 2, point) }.join
    length + knots
  end
  outer = [
    [[0.10, 0.10], [0.10, 0.10], [0.10, 0.10]],
    [[0.10, 0.90], [0.10, 0.90], [0.10, 0.90]],
    [[0.90, 0.50], [0.90, 0.50], [0.90, 0.50]]
  ]
  inner = [
    [[0.35, 0.40], [0.35, 0.40], [0.35, 0.40]],
    [[0.35, 0.60], [0.35, 0.60], [0.35, 0.60]],
    [[0.65, 0.50], [0.65, 0.50], [0.65, 0.50]]
  ]
  paths = [outer]
  paths << inner if include_hole
  u32(3) + u32(flags) + fill_rule + paths.map { |points| subpath.call(points) }.join
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

def solid_color_fill_descriptor(red:, green:, blue:)
  color = descriptor_body(
    name: "RGB Color",
    class_id: "RGBC",
    items: [
      descriptor_item(key: "Rd  ", type: "doub", payload: f64(red)),
      descriptor_item(key: "Grn ", type: "doub", payload: f64(green)),
      descriptor_item(key: "Bl  ", type: "doub", payload: f64(blue))
    ]
  )
  descriptor_block(
    name: "",
    class_id: "SoCo",
    items: [descriptor_item(key: "Clr ", type: "Objc", payload: color)]
  )
end

def gradient_fill_descriptor(gradient_type: "Lnr ")
  color = lambda do |red, green, blue|
    descriptor_body(
      name: "RGB Color",
      class_id: "RGBC",
      items: [
        descriptor_item(key: "Rd  ", type: "doub", payload: f64(red)),
        descriptor_item(key: "Grn ", type: "doub", payload: f64(green)),
        descriptor_item(key: "Bl  ", type: "doub", payload: f64(blue))
      ]
    )
  end
  stop = lambda do |location, red, green, blue|
    descriptor_body(
      name: "",
      class_id: "Clrt",
      items: [
        descriptor_item(key: "Clr ", type: "Objc", payload: color.call(red, green, blue)),
        descriptor_item(
          key: "Type",
          type: "enum",
          payload: descriptor_enum_payload(enum_type: "Clry", value: "UsrS")
        ),
        descriptor_item(key: "Lctn", type: "long", payload: i32(location)),
        descriptor_item(key: "Mdpn", type: "long", payload: i32(50))
      ]
    )
  end
  stops = [stop.call(0, 32, 128, 224), stop.call(4096, 240, 80, 40)]
  gradient = descriptor_body(
    name: "",
    class_id: "Grdn",
    items: [
      descriptor_item(
        key: "GrdF",
        type: "enum",
        payload: descriptor_enum_payload(enum_type: "GrdF", value: "CstS")
      ),
      descriptor_item(key: "Clrs", type: "VlLs", payload: u32(stops.length) + stops.map { |item| "Objc" + item }.join)
    ]
  )
  descriptor_block(
    name: "",
    class_id: "GdFl",
    items: [
      descriptor_item(key: "Grad", type: "Objc", payload: gradient),
      descriptor_item(key: "Type", type: "enum", payload: descriptor_enum_payload(enum_type: "GrdT", value: gradient_type)),
      descriptor_item(key: "Angl", type: "UntF", payload: "#Ang" + f64(0)),
      descriptor_item(key: "Scl ", type: "UntF", payload: "#Prc" + f64(100)),
      descriptor_item(key: "Rvrs", type: "bool", payload: [0].pack("C"))
    ]
  )
end

def vector_stroke_content_payload(key:, descriptor:)
  key.b + descriptor
end

def vector_stroke_descriptor
  dash_set = u32(2) + [6.0, 3.0].map { |value| "UntF" + "#Pnt" + f64(value) }.join
  color = descriptor_body(
    name: "RGB Color",
    class_id: "RGBC",
    items: [
      descriptor_item(key: "Rd  ", type: "doub", payload: f64(240)),
      descriptor_item(key: "Grn ", type: "doub", payload: f64(80)),
      descriptor_item(key: "Bl  ", type: "doub", payload: f64(40))
    ]
  )
  u32(16) + descriptor_block(
    name: "",
    class_id: "vstk",
    items: [
      descriptor_item(key: "strokeStyleVersion", type: "long", payload: i32(2)),
      descriptor_item(key: "strokeEnabled", type: "bool", payload: [1].pack("C")),
      descriptor_item(key: "fillEnabled", type: "bool", payload: [1].pack("C")),
      descriptor_item(key: "strokeStyleLineWidth", type: "UntF", payload: "#Pxl" + f64(2.0)),
      descriptor_item(key: "strokeStyleLineDashOffset", type: "UntF", payload: "#Pnt" + f64(0)),
      descriptor_item(key: "strokeStyleLineDashSet", type: "VlLs", payload: dash_set),
      descriptor_item(
        key: "strokeStyleLineAlignment",
        type: "enum",
        payload: descriptor_enum_payload(enum_type: "strokeStyleLineAlignment", value: "strokeStyleAlignCenter")
      ),
      descriptor_item(
        key: "strokeStyleLineCapType",
        type: "enum",
        payload: descriptor_enum_payload(enum_type: "strokeStyleLineCapType", value: "strokeStyleRoundCap")
      ),
      descriptor_item(
        key: "strokeStyleLineJoinType",
        type: "enum",
        payload: descriptor_enum_payload(enum_type: "strokeStyleLineJoinType", value: "strokeStyleBevelJoin")
      ),
      descriptor_item(key: "strokeStyleMiterLimit", type: "doub", payload: f64(100)),
      descriptor_item(key: "strokeStyleScaleLock", type: "bool", payload: [0].pack("C")),
      descriptor_item(key: "strokeStyleStrokeAdjust", type: "bool", payload: [0].pack("C")),
      descriptor_item(
        key: "strokeStyleBlendMode",
        type: "enum",
        payload: descriptor_enum_payload(enum_type: "BlnM", value: "Nrml")
      ),
      descriptor_item(key: "strokeStyleOpacity", type: "UntF", payload: "#Prc" + f64(75)),
      descriptor_item(key: "strokeStyleContent", type: "Objc", payload: color),
      descriptor_item(key: "strokeStyleResolution", type: "doub", payload: f64(72))
    ]
  )
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

def path_resource_payload(closed:, points:)
  record = ->(selector, point) {
    u16(selector) + point.map { |vertical, horizontal| fixed8_24(vertical) + fixed8_24(horizontal) }.join
  }
  length_selector = closed ? 0 : 3
  knot_selector = closed ? 1 : 4
  # A path length record is 26 bytes: selector (2), knot count (2),
  # and 22 reserved bytes before the first knot record.
  length = u16(length_selector) + u16(points.length) + ("\0" * 22)
  knots = points.each_with_index.map { |point, index| record.call(index.zero? ? knot_selector : knot_selector + 1, point) }.join
  length + knots
end

def path_resource_block(id:, name:, payload:)
  block = "8BIM" + u16(id) + pascal(name, alignment: 2) + u32(payload.bytesize) + payload
  block << "\0" if payload.bytesize.odd?
  block
end

def image_resources(include_icc: false, path_resources: [], alpha_names: [])
  blocks = []
  if include_icc
    profile = "TEST"
    blocks << ("8BIM" + u16(1039) + pascal("", alignment: 2) + u32(profile.bytesize) + profile)
  end
  blocks.concat(path_resources)
  unless alpha_names.empty?
    payload = alpha_names.map { |name| pascal(name, alignment: 2) }.join
    blocks << ("8BIM" + u16(1006) + pascal("", alignment: 2) + u32(payload.bytesize) + payload)
    blocks << "\0" if payload.bytesize.odd?
  end
  payload = blocks.join
  u32(payload.bytesize) + payload
end

def composite_zip(red:, green:, blue:, alpha:)
  u16(2) + Zlib::Deflate.deflate(red + green + blue + alpha)
end

def psd(layer_payload:, composite:, channels: 4, include_icc: false, path_resources: [], alpha_names: [])
  header(channels: channels) + u32(0) + image_resources(
    include_icc: include_icc,
    path_resources: path_resources,
    alpha_names: alpha_names
  ) + layer_payload + composite
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

def extra_alpha_fixture
  red = ([20] * 16).pack("C*")
  green = ([80] * 16).pack("C*")
  blue = ([140] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  selection = [0, 64, 128, 255] * 4
  psd(
    channels: 5,
    layer_payload: u32(0),
    composite: u16(0) + red + green + blue + alpha + selection.pack("C*"),
    alpha_names: ["Selection Alpha"]
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
  blocks = [
    tagged_block("TySh", ""),
    tagged_block("vmsk", vector_mask_payload(flags: 1)),
    tagged_block("SoLd", ""),
    tagged_block("lfx2", ""),
    tagged_block("SoCo", "")
  ]
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

def solid_color_fill_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Brand Blue Fill",
    channels: channels,
    blocks: [tagged_block("SoCo", solid_color_fill_descriptor(red: 32, green: 128, blue: 224))]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def solid_vector_shape_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Editable Vector Shape",
    channels: channels,
    blocks: [
      tagged_block("SoCo", solid_color_fill_descriptor(red: 32, green: 128, blue: 224)),
      tagged_block("vmsk", vector_mask_payload)
    ]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def gradient_vector_shape_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Editable Gradient Shape",
    channels: channels,
    blocks: [
      tagged_block("GdFl", gradient_fill_descriptor),
      tagged_block("vmsk", vector_mask_payload),
      tagged_block("vstk", vector_stroke_descriptor)
    ]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def modern_solid_vector_shape_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  fill = solid_color_fill_descriptor(red: 20, green: 160, blue: 96)
  record = layer_record(
    name: "Modern Solid Shape",
    channels: channels,
    blocks: [
      tagged_block("vsms", vector_mask_payload),
      tagged_block("vscg", vector_stroke_content_payload(key: "SoCo", descriptor: fill))
    ]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def modern_gradient_vector_shape_fixture(name: "Modern Gradient Shape", gradient_type: "Lnr ")
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: name,
    channels: channels,
    blocks: [
      tagged_block("vsms", vector_mask_payload),
      tagged_block(
        "vscg",
        vector_stroke_content_payload(
          key: "GdFl",
          descriptor: gradient_fill_descriptor(gradient_type: gradient_type)
        )
      )
    ]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def stroked_vector_shape_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Editable Stroked Shape",
    channels: channels,
    blocks: [
      tagged_block("SoCo", solid_color_fill_descriptor(red: 32, green: 128, blue: 224)),
      tagged_block("vmsk", vector_mask_payload),
      tagged_block("vstk", vector_stroke_descriptor)
    ]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def gradient_fill_fixture
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Sunset Gradient Fill",
    channels: channels,
    blocks: [tagged_block("GdFl", gradient_fill_descriptor)]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha
  )
end

def vector_mask_fixture(payload: vector_mask_payload, path_resources: [])
  pixel = ([180] * 16).pack("C*")
  alpha = ([255] * 16).pack("C*")
  channels = {
    -1 => raw_channel(alpha),
    0 => raw_channel(pixel),
    1 => raw_channel(pixel),
    2 => raw_channel(pixel)
  }
  record = layer_record(
    name: "Vector Triangle",
    channels: channels,
    blocks: [tagged_block("vmsk", payload)],
    frame: [0, 0, HEIGHT, WIDTH]
  )
  layer_info = i16(1) + record + channels.values.join
  layer_info << "\0" if layer_info.bytesize.odd?
  layer_and_mask = u32(layer_info.bytesize) + layer_info + u32(0)
  psd(
    layer_payload: u32(layer_and_mask.bytesize) + layer_and_mask,
    composite: u16(0) + pixel + pixel + pixel + alpha,
    path_resources: path_resources
  )
end

def multi_vector_mask_fixture
  vector_mask_fixture(payload: vector_mask_payload(include_hole: true))
end

def path_resource_fixture
  closed = path_resource_block(
    id: 2000,
    name: "Triangle Path",
    payload: path_resource_payload(
      closed: true,
      points: [
        [[0.10, 0.10], [0.10, 0.10], [0.10, 0.10]],
        [[0.10, 0.90], [0.10, 0.90], [0.10, 0.90]],
        [[0.90, 0.50], [0.90, 0.50], [0.90, 0.50]]
      ]
    )
  )
  open_path = path_resource_block(
    id: 2001,
    name: "Open Guide",
    payload: path_resource_payload(
      closed: false,
      points: [
        [[0.20, 0.20], [0.20, 0.20], [0.20, 0.20]],
        [[0.80, 0.80], [0.80, 0.80], [0.80, 0.80]]
      ]
    )
  )
  vector_mask_fixture(path_resources: [closed, open_path])
end

FileUtils.mkdir_p(OUTPUT_DIR)
fixtures = {
  "zip-group-mask.psd" => group_mask_fixture,
  "zip-composite.psd" => composite_only_fixture,
  "extra-alpha.psd" => extra_alpha_fixture,
  "unsupported-features.psd" => unsupported_features_fixture,
  "editable-text.psd" => editable_text_fixture,
  "solid-color-fill.psd" => solid_color_fill_fixture,
  "solid-vector-shape.psd" => solid_vector_shape_fixture,
  "gradient-vector-shape.psd" => gradient_vector_shape_fixture,
  "modern-solid-vector-shape.psd" => modern_solid_vector_shape_fixture,
  "modern-gradient-vector-shape.psd" => modern_gradient_vector_shape_fixture,
  "modern-radial-vector-shape.psd" => modern_gradient_vector_shape_fixture(
    name: "Modern Radial Shape",
    gradient_type: "Rdl "
  ),
  "modern-reflected-vector-shape.psd" => modern_gradient_vector_shape_fixture(
    name: "Modern Reflected Shape",
    gradient_type: "Rflc"
  ),
  "modern-diamond-vector-shape.psd" => modern_gradient_vector_shape_fixture(
    name: "Modern Diamond Shape",
    gradient_type: "Dmnd"
  ),
  "modern-angle-vector-shape.psd" => modern_gradient_vector_shape_fixture(
    name: "Unsupported Angle Shape",
    gradient_type: "Angl"
  ),
  "stroked-vector-shape.psd" => stroked_vector_shape_fixture,
  "gradient-fill.psd" => gradient_fill_fixture,
  "vector-mask.psd" => vector_mask_fixture,
  "vector-mask-multi.psd" => multi_vector_mask_fixture,
  "path-resources.psd" => path_resource_fixture
}
fixtures.each do |name, bytes|
  File.binwrite(File.join(OUTPUT_DIR, name), bytes)
end

expectations = {
  "zip-group-mask.psd" => %w[zip zip_prediction group raster_mask fill_opacity layer_locks],
  "zip-composite.psd" => %w[zip flattened_composite],
  "extra-alpha.psd" => %w[raw flattened_composite additional_alpha_channel alpha_name],
  "unsupported-features.psd" => %w[compatibility_report unsupported_semantic_features],
  "editable-text.psd" => %w[editable_text font_size color alignment],
  "solid-color-fill.psd" => %w[editable_solid_color_fill rgb_descriptor],
  "solid-vector-shape.psd" => %w[editable_vector_shape solid_fill vector_mask],
  "gradient-vector-shape.psd" => %w[editable_vector_shape gradient_fill vector_mask vector_stroke dash_pattern],
  "modern-solid-vector-shape.psd" => %w[editable_vector_shape vscg solid_fill vector_mask],
  "modern-gradient-vector-shape.psd" => %w[editable_vector_shape vscg gradient_fill vector_mask],
  "modern-radial-vector-shape.psd" => %w[editable_vector_shape vscg radial_gradient vector_mask],
  "modern-reflected-vector-shape.psd" => %w[editable_vector_shape vscg reflected_gradient vector_mask],
  "modern-diamond-vector-shape.psd" => %w[editable_vector_shape vscg diamond_gradient vector_mask],
  "modern-angle-vector-shape.psd" => %w[compatibility_report raster_fallback angle_gradient],
  "stroked-vector-shape.psd" => %w[editable_vector_shape solid_fill vector_mask vector_stroke dash_pattern],
  "gradient-fill.psd" => %w[editable_gradient_fill linear_color_stops],
  "vector-mask.psd" => %w[editable_vector_mask closed_path bezier_points],
  "vector-mask-multi.psd" => %w[editable_vector_mask multiple_subpaths even_odd_hole],
  "path-resources.psd" => %w[saved_path closed_path open_path]
}
manifest = {
  generator: "scripts/generate_psd_compatibility_fixtures.rb",
  specification: "Adobe Photoshop File Formats Specification",
  fixtures: fixtures.map do |name, bytes|
    { file: name, sha256: Digest::SHA256.hexdigest(bytes), expected: expectations.fetch(name) }
  end
}
File.write(File.join(OUTPUT_DIR, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
