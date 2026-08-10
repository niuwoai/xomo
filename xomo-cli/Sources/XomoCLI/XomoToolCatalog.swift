import Foundation

enum XomoToolCatalog {
    static var fallbackTools: [[String: Any]] {
        entries.map { name, description in
            var tool: [String: Any] = [
                "name": name,
                "description": description,
                "inputSchema": [
                    "type": "object",
                    "properties": [:],
                    "additionalProperties": true
                ]
            ]
            if name == "xomo.layer.list" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "figmaBindings": ["type": "string", "enum": ["all", "bound", "unbound"]],
                        "figmaConstraints": ["type": "string", "enum": ["all", "constrained", "overridden", "conflicted"]],
                        "figmaSource": ["type": "string", "enum": ["all", "imported", "local"]],
                        "figmaFileKey": ["type": "string"],
                        "figmaNodeId": ["type": "string"],
                        "figmaNodeType": ["type": "string"],
                        "figmaComponentRole": ["type": "string", "enum": ["all", "none", "COMPONENT", "COMPONENT_SET", "INSTANCE"]]
                    ],
                    "additionalProperties": true
                ]
            }
            if name == "xomo.clipboard.action" {
                tool["description"] = "Copy, cut, and paste through the system clipboard, including Xomo in-place layer paste."
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": [
                                "pasteAsLayer",
                                "pasteIntoSelection",
                                "pasteInPlace",
                                "copySelection",
                                "cutSelection",
                                "copyMerged",
                                "copySelectedLayers"
                            ]
                        ]
                    ],
                    "required": ["action"],
                    "additionalProperties": true
                ]
            }
            if name == "xomo.figma.image_fill" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "action": ["type": "string", "enum": ["list", "set"]],
                        "property": ["type": "string", "enum": ["scaleMode", "scalingFactor", "rotation", "offsetX", "offsetY", "m11", "m12", "m21", "m22", "filtersEnabled"]],
                        "scaleMode": ["type": "string", "enum": ["FILL", "FIT", "CROP", "TILE", "STRETCH"]],
                        "value": ["type": "number"],
                        "enabled": ["type": "boolean"]
                    ],
                    "required": ["action"],
                    "additionalProperties": true
                ]
            }
            if name == "xomo.figma.size_constraints" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "action": ["type": "string", "enum": ["list", "set", "clear", "reset", "resetAll", "resolve", "resolveAll"]],
                        "field": ["type": "string", "enum": ["minWidth", "maxWidth", "minHeight", "maxHeight"]],
                        "axis": ["type": "string", "enum": ["width", "height"]],
                        "value": ["type": "number"]
                    ],
                    "required": ["action"],
                    "additionalProperties": true
                ]
            }
            if name == "xomo.object.select_at" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "x": ["type": "number"],
                        "y": ["type": "number"],
                        "mode": ["type": "string", "enum": ["auto", "component", "deep"]],
                        "extend": ["type": "boolean"],
                        "clearOnMiss": ["type": "boolean"]
                    ],
                    "required": ["x", "y"],
                    "additionalProperties": false
                ]
            }
            if name == "xomo.layer.transform_reference" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "action": ["type": "string", "enum": ["set", "reset"]],
                        "x": ["type": "number"],
                        "y": ["type": "number"]
                    ],
                    "required": ["action"],
                    "additionalProperties": false
                ]
            }
            if name == "xomo.paint.stroke" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "tool": ["type": "string", "enum": ["brush", "eraser"]],
                        "points": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number"],
                                    "y": ["type": "number"],
                                    "pressure": ["type": "number", "minimum": 0, "maximum": 1],
                                    "tiltX": ["type": "number", "minimum": -1, "maximum": 1],
                                    "tiltY": ["type": "number", "minimum": -1, "maximum": 1]
                                ],
                                "required": ["x", "y"],
                                "additionalProperties": false
                            ],
                            "minItems": 1
                        ],
                        "size": ["type": "number"],
                        "opacity": ["type": "number", "minimum": 0, "maximum": 1],
                        "hardness": ["type": "number", "minimum": 0, "maximum": 1],
                        "flow": ["type": "number", "minimum": 1, "maximum": 100],
                        "spacing": ["type": "number", "minimum": 1, "maximum": 200],
                        "pressureSize": ["type": "boolean"],
                        "pressureOpacity": ["type": "boolean"],
                        "pressureFlow": ["type": "boolean"],
                        "pressureSensitivity": ["type": "number", "minimum": 0, "maximum": 100],
                        "minimumDiameter": ["type": "number", "minimum": 0, "maximum": 100],
                        "minimumOpacity": ["type": "number", "minimum": 0, "maximum": 100],
                        "minimumFlow": ["type": "number", "minimum": 0, "maximum": 100],
                        "tiltShape": ["type": "boolean"],
                        "roundness": ["type": "number", "minimum": 10, "maximum": 100],
                        "angle": ["type": "number", "minimum": -180, "maximum": 180],
                        "smoothing": ["type": "number", "minimum": 0, "maximum": 100]
                    ],
                    "required": ["points"],
                    "additionalProperties": false
                ]
            }
            if name == "xomo.paint.special" {
                tool["inputSchema"] = [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["setCloneSource", "cloneStamp", "setHealingSource", "healing", "patch", "dodge", "burn", "sponge", "blur", "sharpen", "smudge", "redEye", "paintBucket"]
                        ],
                        "points": ["type": "array"],
                        "x": ["type": "number"],
                        "y": ["type": "number"],
                        "size": ["type": "number"],
                        "opacity": ["type": "number"],
                        "flow": ["type": "number", "minimum": 0, "maximum": 1],
                        "strength": ["type": "number"],
                        "exposure": ["type": "number"],
                        "hardness": ["type": "number"],
                        "feather": ["type": "number"],
                        "toneRange": ["type": "string", "enum": ["shadows", "midtones", "highlights"]],
                        "protectTones": ["type": "boolean"],
                        "airbrush": ["type": "boolean"],
                        "airbrushPulses": ["type": "integer", "minimum": 0, "maximum": 80],
                        "mode": ["type": "string", "enum": ["source", "destination"]],
                        "healingMode": ["type": "string", "enum": ["source", "spot"]],
                        "spongeMode": ["type": "string", "enum": ["saturate", "desaturate"]],
                        "spongeVibrance": ["type": "boolean"],
                        "fingerPainting": [
                            "type": "boolean",
                            "description": "Start each Smudge stroke with the current foreground color"
                        ],
                        "sampleAllLayers": [
                            "type": "boolean",
                            "description": "Smudge from the composite of all visible layers into the active layer"
                        ],
                        "pressureSize": [
                            "type": "boolean",
                            "description": "Use point pressure to control retouch brush diameter"
                        ],
                        "pressureSensitivity": ["type": "number", "minimum": 0, "maximum": 100],
                        "aligned": ["type": "boolean"],
                        "sampleSource": ["type": "string", "enum": ["currentLayer", "currentAndBelow", "allVisible"]]
                    ],
                    "required": ["action"],
                    "additionalProperties": true
                ]
            }
            return tool
        }
    }

    private static let entries: [(String, String)] = [
        ("xomo.app.status", "Get Xomo app and active editor status."),
        ("xomo.document.get", "Inspect the active Xomo document and canvas."),
        ("xomo.document.create", "Replace the active document with a new preset or custom canvas."),
        ("xomo.project.export", "Serialize the complete layered project."),
        ("xomo.project.import", "Replace the active document from qpicproject data."),
        ("xomo.import.image", "Import an encoded image as an editable layer."),
        ("xomo.psd.inspect", "Inspect a local PSD compatibility report without importing or changing the active document."),
        ("xomo.psd.open", "Open a local PSD asynchronously in the active Xomo editor."),
        ("xomo.psd.save", "Save the current layered Xomo document as a PSD file."),
        ("xomo.tool.list", "List all image editor tools."),
        ("xomo.tool.select", "Select the active editor tool."),
        ("xomo.layer.list", "List layers, hierarchy, bounds, visibility, locks, opacity, blend mode, and preserved Figma source, bindings, and size constraints, with optional filters."),
        ("xomo.layer.selection_bounds", "Inspect selected object bounds, transform reference point, and live move, resize, or rotate preview context, including original bounds, movement, size, scale, and rotation deltas."),
        ("xomo.layer.transform_reference", "Set or reset the transform reference point for the current transformable layer selection without changing document history."),
        ("xomo.object.select_at", "Select the frontmost visible canvas object at a point using Xomo's alpha-aware component and layer hit testing."),
        ("xomo.figma.bindings", "List or copy the deduplicated Figma variable bindings from the current layer selection."),
        ("xomo.figma.link", "Validate and canonicalize a Figma link without network access or credential storage."),
        ("xomo.figma.component_properties", "List, locally override, or reset preserved Figma component properties on the selected layer."),
        ("xomo.figma.size_constraints", "List current and imported Figma min/max size constraints, locally set, clear or reset fields, or explicitly resolve a conflicting axis by using its minimum."),
        ("xomo.figma.image_fill", "List or edit the retained source, transform, and filter controls of the selected Figma image fill."),
        ("xomo.layer.select", "Select a layer by UUID."),
        ("xomo.layer.create", "Create a pixel, group, text, adjustment, filter, or fill layer."),
        ("xomo.layer.delete", "Delete unlocked selected layer roots as complete subtrees and preserve a visible selection fallback."),
        ("xomo.layer.duplicate", "Duplicate selected layer roots as hierarchy-safe subtrees within their original parents."),
        ("xomo.layer.rename", "Rename the primary selected layer."),
        ("xomo.layer.set_visibility", "Set layer visibility."),
        ("xomo.layer.set_lock", "Set the full lock state of a layer."),
        ("xomo.layer.set_opacity", "Set selected layer opacity."),
        ("xomo.layer.set_blend_mode", "Set selected layer blend mode."),
        ("xomo.layer.nudge", "Move the selection or selected layers by a canvas delta."),
        ("xomo.layer.order", "Move selected layer subtrees in the current visible hierarchy order."),
        ("xomo.layer.group", "Group selected editable sibling subtrees while leaving locked items in place."),
        ("xomo.layer.ungroup", "Ungroup selected editable groups while preserving unaffected selection."),
        ("xomo.layer.merge_down", "Merge the selected visible layer into its adjacent lower pixel sibling, or flatten the selected group subtree."),
        ("xomo.layer.merge_selected", "Merge editable selected sibling subtrees while preserving locked selections."),
        ("xomo.layer.merge_visible", "Merge all visible layers."),
        ("xomo.layer.stamp_visible", "Create a stamped layer from visible content."),
        ("xomo.layer.stamp_selected", "Create a stamped layer from selected layer subtrees."),
        ("xomo.layer.flatten", "Flatten visible content onto an opaque locked background and discard hidden layers."),
        ("xomo.layer.transform", "Scale, rotate, flip, fit, trim, or rasterize selected layers."),
        ("xomo.layer.rasterize", "Rasterize type, shape, fill content, vector masks, Smart Objects, layer styles, or complete selected layers."),
        ("xomo.layer.align", "Align or distribute selected layers."),
        ("xomo.layer.style", "Copy layer styles; paste, clear, hide, or show layers with actual affected counts; browse built-in styles, or preview, import, manage, favorite, and revisit portable layer style presets."),
        ("xomo.layer.style_settings", "Set effect scale, stroke width, or stroke opacity with actual updated-layer counts and edit detailed layer style properties."),
        ("xomo.layer.selection", "Select layers by state, relationship, kind, blend mode, or label."),
        ("xomo.layer.link", "Link, unlink, or select linked layers."),
        ("xomo.layer.smart_object", "Convert and manage embedded smart object layers."),
        ("xomo.layer.properties", "Set fill, Blend If, mask, clipping, locks, labels, and visibility."),
        ("xomo.layer.action", "Run background conversion, recursive group expansion, hierarchy-safe group movement, clipping, and stamping commands."),
        ("xomo.layer_comp.list", "List saved layer composition states."),
        ("xomo.layer_comp.action", "Create and manage saved layer compositions."),
        ("xomo.selection.get", "Inspect the active pixel selection."),
        ("xomo.selection.all", "Select the full canvas."),
        ("xomo.selection.rectangle", "Create a rectangular canvas selection."),
        ("xomo.selection.ellipse", "Create an elliptical canvas selection."),
        ("xomo.selection.lasso", "Create a polygonal lasso selection."),
        ("xomo.selection.magic", "Create a magic-wand selection."),
        ("xomo.selection.quick", "Create a quick selection from sampled points."),
        ("xomo.selection.quick_mask", "Inspect and edit Photoshop-style quick mask state."),
        ("xomo.selection.clear", "Deselect the current selection."),
        ("xomo.selection.invert", "Invert the current selection."),
        ("xomo.selection.feather", "Feather the current selection."),
        ("xomo.selection.smooth", "Smooth the current selection boundary."),
        ("xomo.selection.edit", "Fill, stroke, clear, duplicate, copy, or cut selected pixels."),
        ("xomo.selection.modify", "Save, restore, transform, clean, or nudge the pixel selection."),
        ("xomo.clipboard.action", "Copy, cut, and paste through the system clipboard, including Xomo in-place layer paste."),
        ("xomo.channel.list", "List alpha channels."),
        ("xomo.channel.create", "Create a blank alpha channel."),
        ("xomo.channel.select", "Select an alpha channel."),
        ("xomo.channel.rename", "Rename an alpha channel."),
        ("xomo.channel.delete", "Delete an alpha channel."),
        ("xomo.channel.duplicate", "Duplicate an alpha channel."),
        ("xomo.channel.action", "Apply selection and mask operations to an alpha channel."),
        ("xomo.history.list", "List document history states."),
        ("xomo.history.undo", "Undo the last operation."),
        ("xomo.history.redo", "Redo the last undone operation."),
        ("xomo.history.restore", "Restore a history state by UUID."),
        ("xomo.history.snapshot_list", "List named history snapshots."),
        ("xomo.history.action", "Truncate history or create and manage named snapshots."),
        ("xomo.canvas.resize_image", "Resize the image and all layer content."),
        ("xomo.canvas.resize_canvas", "Resize the canvas without scaling content."),
        ("xomo.canvas.crop_to_selection", "Crop the document to the current selection."),
        ("xomo.canvas.transform", "Rotate, flip, crop, trim, or reveal the complete canvas."),
        ("xomo.component.list", "List editable Xomo UI components and themes."),
        ("xomo.component.tokens", "Read, import, export, apply, clear, or refresh local component design tokens as a .xomotokens.json file."),
        ("xomo.component.insert", "Insert an editable UI component as native layers."),
        ("xomo.component.instance", "Create a component master, link selected components, synchronize linked instances, or detach instances."),
        ("xomo.color.get", "Read foreground and background colors."),
        ("xomo.color.set", "Set foreground or background color."),
        ("xomo.color.swap", "Swap foreground and background colors."),
        ("xomo.color.reset", "Reset foreground and background colors."),
        ("xomo.brush.preset", "List, create, apply, or delete persisted brush presets."),
        ("xomo.paint.stroke", "Paint a pressure-aware brush or eraser stroke with size, hardness, opacity, flow, spacing, minimum diameter, roundness, angle, smoothing, and tablet-dynamics controls."),
        ("xomo.paint.gradient", "Paint a gradient between canvas points."),
        ("xomo.paint.special", "Use clone or healing with explicit source and sampling options, source/destination patching, exposure-, tonal-range-, tone-protection-, and gradual-airbrush-aware dodge and burn, pressure-size-, flow-, and vibrance-aware sponge, strength-aware blur, sharpen, and smudge, red-eye, and paint-bucket tools."),
        ("xomo.shape.create", "Create an editable rectangle or ellipse with solid or multi-stop linear-gradient fill, independent stroke, corner radii, and superellipse smoothing."),
        ("xomo.shape.get", "Inspect fill kind, editable multi-stop linear gradient, independent stroke, corner radii, and smoothing on the selected shape."),
        ("xomo.shape.update", "Update only the specified fill kind, multi-stop linear gradient, stroke, corner radii, and smoothing properties."),
        ("xomo.text.create", "Create editable point text or a fixed/auto-height paragraph text box with native letter-case, paragraph spacing, overflow ellipsis, and vertical alignment."),
        ("xomo.text.get", "Inspect selected editable text, including raw/display text, letter case, paragraph spacing, auto-height, overflow ellipsis, vertical alignment, and box sizing."),
        ("xomo.text.update", "Update selected text content, native letter case, typography, paragraph spacing, auto-height, overflow ellipsis, vertical alignment, and text box dimensions."),
        ("xomo.text.convert", "Convert selected editable text layers between point and paragraph text."),
        ("xomo.text.fitBox", "Fit selected paragraph text boxes to content or expand overflowing boxes."),
        ("xomo.mask.action", "Create, delete, enable, or link a layer mask."),
        ("xomo.path.get", "Inspect the selected editable vector path."),
        ("xomo.path.action", "Create and edit vector paths, anchors, subpaths, and masks."),
        ("xomo.path.saved", "List and manage independent named paths stored in the document."),
        ("xomo.layer.effect", "Toggle a layer effect."),
        ("xomo.guide.list", "List guides and grid settings."),
        ("xomo.guide.add", "Add a guide."),
        ("xomo.guide.delete", "Delete a guide."),
        ("xomo.guide.clear", "Delete all guides."),
        ("xomo.guide.settings", "Set guide and grid behavior."),
        ("xomo.view.zoom", "Set or change canvas zoom."),
        ("xomo.view.pan", "Nudge, center, or reset the canvas viewport without changing document History."),
        ("xomo.smart_filter.list", "List smart filters."),
        ("xomo.smart_filter.add", "Add a smart filter and return the added layer count."),
        ("xomo.smart_filter.toggle", "Toggle a smart filter and return the toggled layer count."),
        ("xomo.smart_filter.clear", "Clear smart filters and return the cleared layer count."),
        ("xomo.smart_filter.manage", "Update, duplicate, remove, or reorder a smart filter; mutations return their affected layer count."),
        ("xomo.filter.list", "List raster filters."),
        ("xomo.filter.apply", "Apply a raster filter to selected layers."),
        ("xomo.filter.configure", "Configure filter settings and destination; smart-filter creation returns the added layer count."),
        ("xomo.adjustment.list", "List image adjustments."),
        ("xomo.adjustment.apply", "Apply an adjustment to selected layers."),
        ("xomo.adjustment.configure", "Configure detailed adjustment settings and destination."),
        ("xomo.export.render", "Render document data as PNG, JPEG, WebP, PDF, SVG, or PSD.")
    ]
}
