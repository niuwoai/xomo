import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSVGImportTests {
    @Test func singleCompoundPathImportsEditableGeometryAndPresentation() throws {
        let data = Data(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
              <g opacity="0.5" fill="#33669980" fill-opacity="0.8"
                 stroke="rgb(240, 80, 32)" stroke-opacity="0.75"
                 stroke-width="4px" stroke-linecap="square" stroke-linejoin="bevel"
                 stroke-miterlimit="7" stroke-dasharray="5" stroke-dashoffset="-2">
                <path fill-rule="evenodd"
                      d="M 10 20 C 30 0 70 0 90 20 L 110 100 Z M 40 40 L 70 40 L 55 70 Z" />
              </g>
            </svg>
            """.utf8
        )

        let imported = try #require(XomoEditableSVGImporter.parse(data))
        let content = imported.content
        let fill = try #require(content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(content.kind == .path)
        #expect(content.isPathClosed)
        #expect(content.allEditablePathSubpaths.count == 2)
        let firstAnchor = try #require(content.editablePathAnchors.first)
        let firstControl = try #require(firstAnchor.outControl)
        #expect(abs((firstControl.x - firstAnchor.point.x) - 20) < 0.001)
        #expect(abs((firstControl.y - firstAnchor.point.y) + 20) < 0.001)
        #expect(imported.size.width > 100)
        #expect(imported.size.height > 100)
        #expect(abs(fill.redComponent - 0.2) < 0.001)
        #expect(abs(fill.greenComponent - 0.4) < 0.001)
        #expect(abs(fill.blueComponent - 0.6) < 0.001)
        #expect(abs(content.fillOpacity - (128.0 / 255.0 * 0.8 * 0.5)) < 0.001)
        #expect(abs(stroke.redComponent - (240.0 / 255.0)) < 0.001)
        #expect(abs(content.strokeOpacity - 0.375) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .square)
        #expect(content.strokeJoin == .bevel)
        #expect(content.strokeMiterLimit == 7)
        #expect(content.strokeDashPattern == [5, 5])
        #expect(content.strokeDashOffset == -2)
    }

    @Test func unsupportedSVGStructuresFailWithoutPartialImport() {
        let unsupported = [
            "<svg><path d='M0 0 L10 10' fill='none' stroke='black'/><path d='M20 20 L30 30' fill='none' stroke='black'/></svg>",
            "<svg><g transform='translate(10 10)'><path d='M0 0 L10 10' fill='none' stroke='black'/></g></svg>",
            "<svg><path style='mix-blend-mode:multiply' d='M0 0 L10 0 L10 10 Z'/></svg>",
            "<svg><path d='M0 0 L10 0 Z M20 0 L30 0' fill='none' stroke='black'/></svg>",
            "<svg><path d='M0 0 L10 0 M20 0 L30 0' stroke='black'/></svg>",
            "<svg><path d='M0 0 L20 0 L20 20 Z M5 5 L10 5 L10 10 Z'/></svg>",
            "<!DOCTYPE svg [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><svg><path d='M0 0 L10 0 Z'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func currentColorPaintInheritsThroughGroupsWithIndependentOpacity() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg color="#33669980">
              <g color="currentColor" opacity="0.5">
                <path d="M 0 0 L 20 0 L 10 20 Z"
                      fill="currentColor" fill-opacity="0.5"
                      stroke="currentColor" stroke-opacity="0.25" stroke-width="2" />
              </g>
            </svg>
            """.utf8
        )))
        let fill = try #require(imported.content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(imported.content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(abs(fill.redComponent - 0.2) < 0.001)
        #expect(abs(fill.greenComponent - 0.4) < 0.001)
        #expect(abs(fill.blueComponent - 0.6) < 0.001)
        #expect(abs(stroke.redComponent - 0.2) < 0.001)
        #expect(abs(stroke.greenComponent - 0.4) < 0.001)
        #expect(abs(stroke.blueComponent - 0.6) < 0.001)
        #expect(abs(imported.content.fillOpacity - (128.0 / 255.0 * 0.5 * 0.5)) < 0.001)
        #expect(abs(imported.content.strokeOpacity - (128.0 / 255.0 * 0.25 * 0.5)) < 0.001)
    }

    @Test func currentColorUsesSVGBlackDefaultAndRejectsOnlyInvalidReferencedPaint() throws {
        let defaultPaint = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><path d='M0 0 L20 0 L10 20 Z' fill='currentColor'/></svg>".utf8
        )))
        let black = try #require(defaultPaint.content.fillColor.usingColorSpace(.deviceRGB))
        #expect(black.redComponent == 0)
        #expect(black.greenComponent == 0)
        #expect(black.blueComponent == 0)

        #expect(XomoEditableSVGImporter.parse(Data(
            "<svg color='not-a-color'><path d='M0 0 L20 0 L10 20 Z' fill='currentColor'/></svg>".utf8
        )) == nil)
        #expect(XomoEditableSVGImporter.parse(Data(
            "<svg color='not-a-color'><path d='M0 0 L20 0 L10 20 Z' fill='red'/></svg>".utf8
        )) != nil)
    }

    @Test func allStandardNamedColorsImportWithExactCaseInsensitiveRGBValues() throws {
        let namedColors = XomoEditableSVGImporter.namedColorHexValues
        #expect(namedColors.count == 148)
        let canonicalTable = namedColors
            .sorted(by: { $0.key < $1.key })
            .map { String(format: "%@=%06x\n", $0.key, $0.value) }
            .joined()
        var tableFingerprint: UInt64 = 14_695_981_039_346_656_037
        for byte in canonicalTable.utf8 {
            tableFingerprint ^= UInt64(byte)
            tableFingerprint &*= 1_099_511_628_211
        }
        #expect(tableFingerprint == 0x081B_BF6A_EC6E_4734)

        for (name, value) in namedColors.sorted(by: { $0.key < $1.key }) {
            let source = """
            <svg><path d='M0 0 L20 0 L10 20 Z'
                       fill='\(name.uppercased())' stroke='\(name)' stroke-width='2'/></svg>
            """
            let imported = try #require(XomoEditableSVGImporter.parse(Data(source.utf8)))
            let fill = try #require(imported.content.fillColor.usingColorSpace(.deviceRGB))
            let stroke = try #require(imported.content.strokeColor.usingColorSpace(.deviceRGB))
            let expectedRed = CGFloat((value >> 16) & 0xFF) / 255
            let expectedGreen = CGFloat((value >> 8) & 0xFF) / 255
            let expectedBlue = CGFloat(value & 0xFF) / 255

            #expect(abs(fill.redComponent - expectedRed) < 0.001)
            #expect(abs(fill.greenComponent - expectedGreen) < 0.001)
            #expect(abs(fill.blueComponent - expectedBlue) < 0.001)
            #expect(abs(stroke.redComponent - expectedRed) < 0.001)
            #expect(abs(stroke.greenComponent - expectedGreen) < 0.001)
            #expect(abs(stroke.blueComponent - expectedBlue) < 0.001)
        }

        #expect(namedColors["aqua"] == namedColors["cyan"])
        #expect(namedColors["fuchsia"] == namedColors["magenta"])
        #expect(namedColors["gray"] == namedColors["grey"])
        #expect(namedColors["darkslategray"] == namedColors["darkslategrey"])
        #expect(namedColors["rebeccapurple"] == 0x663399)
        #expect(namedColors["orange"] == 0xFFA500)

        #expect(XomoEditableSVGImporter.parse(Data(
            "<svg><path d='M0 0 L20 0 L10 20 Z' fill='not-a-standard-color'/></svg>".utf8
        )) == nil)
    }

    @Test func modernSpaceSeparatedRGBColorsPreservePercentagesAlphaAndCurrentColor() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg color="rgb(20% 40% 60% / 80%)">
              <path d="M0 0 L20 0 L10 20 Z"
                    fill="currentColor" fill-opacity="0.5"
                    stroke="rgba(240 80 32 / 50%)" stroke-width="2" />
            </svg>
            """.utf8
        )))
        let content = imported.content
        let fill = try #require(content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(abs(fill.redComponent - 0.2) < 0.001)
        #expect(abs(fill.greenComponent - 0.4) < 0.001)
        #expect(abs(fill.blueComponent - 0.6) < 0.001)
        #expect(abs(content.fillOpacity - 0.4) < 0.001)
        #expect(abs(stroke.redComponent - (240.0 / 255.0)) < 0.001)
        #expect(abs(stroke.greenComponent - (80.0 / 255.0)) < 0.001)
        #expect(abs(stroke.blueComponent - (32.0 / 255.0)) < 0.001)
        #expect(abs(content.strokeOpacity - 0.5) < 0.001)
    }

    @Test func malformedOrMixedFunctionalColorSyntaxIsRejectedBeforeImport() {
        let invalidPaints = [
            "rgb(20%, 40% 60%)",
            "rgb(20% 40% 60%, 80%)",
            "rgb(20% 40% / 80%)",
            "rgb(20% 40% 60% /)",
            "rgb(20% 40% 60% / 80% / 20%)",
            "rgba(20%, 40%, 60%)",
            "rgb(20%, 40%, 60%, 0.8)"
        ]
        for paint in invalidPaints {
            let source = "<svg><path d='M0 0 L20 0 L10 20 Z' fill='\(paint)'/></svg>"
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func HSLColorsPreserveModernAlphaLegacySyntaxAndAngleUnits() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg color="hsl(-240deg 100% 50% / 80%)">
              <path d="M0 0 L20 0 L10 20 Z"
                    fill="currentColor" fill-opacity="0.5"
                    stroke="hsla(0.5turn, 100%, 50%, 0.5)" stroke-width="2" />
            </svg>
            """.utf8
        )))
        let content = imported.content
        let fill = try #require(content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(abs(fill.redComponent) < 0.001)
        #expect(abs(fill.greenComponent - 1) < 0.001)
        #expect(abs(fill.blueComponent) < 0.001)
        #expect(abs(content.fillOpacity - 0.4) < 0.001)
        #expect(abs(stroke.redComponent) < 0.001)
        #expect(abs(stroke.greenComponent - 1) < 0.001)
        #expect(abs(stroke.blueComponent - 1) < 0.001)
        #expect(abs(content.strokeOpacity - 0.5) < 0.001)

        let greenAngles = ["120", "120deg", "133.333333333grad", "2.094395102rad", "0.333333333turn"]
        for angle in greenAngles {
            let source = "<svg><path d='M0 0 L20 0 L10 20 Z' fill='hsl(\(angle) 100% 50%)'/></svg>"
            let angleImport = try #require(XomoEditableSVGImporter.parse(Data(source.utf8)))
            let color = try #require(angleImport.content.fillColor.usingColorSpace(.deviceRGB))
            #expect(abs(color.redComponent) < 0.001)
            #expect(abs(color.greenComponent - 1) < 0.001)
            #expect(abs(color.blueComponent) < 0.001)
        }
    }

    @Test func malformedOrMixedHSLColorSyntaxIsRejectedBeforeImport() {
        let invalidPaints = [
            "hsl(120, 100% 50%)",
            "hsl(120 100% 50%, 0.8)",
            "hsl(120, 100%, 50% / 0.8)",
            "hsl(120 100 50%)",
            "hsl(120 101% 50%)",
            "hsl(120 100% -1%)",
            "hsl(120foo 100% 50%)",
            "hsl(120 100% 50% /)",
            "hsl(120 100% 50% / 0.8 / 0.5)",
            "hsl(120, 100%, 50%, 0.8)",
            "hsla(120, 100%, 50%)",
            "hsla(120, 100%, 50%, 1.1)"
        ]
        for paint in invalidPaints {
            let source = "<svg><path d='M0 0 L20 0 L10 20 Z' fill='\(paint)'/></svg>"
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func inlinePresentationStyleOverridesAttributesAndInheritsThroughGroups() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg color="red" fill="yellow"
                 style="color: hsl(210 50% 40%); fill: #336699; stroke: #f05020;
                        stroke-width: 4px; stroke-linecap: square; stroke-linejoin: bevel;
                        stroke-miterlimit: 7; stroke-dasharray: 5; stroke-dashoffset: -2">
              <g opacity="0.9" style="opacity: 50%; fill: inherit; stroke: inherit">
                <path fill="magenta" stroke="cyan" fill-opacity="1" stroke-opacity="1"
                      style="fill: currentColor; fill-opacity: 40%; stroke: inherit; stroke-opacity: 50%;
                             fill-rule: evenodd; stroke-dasharray: 3 4; stroke-dasharray: 5"
                      d="M0 0 L30 0 L30 30 L0 30 Z M10 10 L20 10 L20 20 L10 20 Z" />
              </g>
            </svg>
            """.utf8
        )))
        let content = imported.content
        let fill = try #require(content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(content.allEditablePathSubpaths.count == 2)
        #expect(abs(fill.redComponent - 0.2) < 0.001)
        #expect(abs(fill.greenComponent - 0.4) < 0.001)
        #expect(abs(fill.blueComponent - 0.6) < 0.001)
        #expect(abs(content.fillOpacity - 0.2) < 0.001)
        #expect(abs(stroke.redComponent - (240.0 / 255.0)) < 0.001)
        #expect(abs(stroke.greenComponent - (80.0 / 255.0)) < 0.001)
        #expect(abs(stroke.blueComponent - (32.0 / 255.0)) < 0.001)
        #expect(abs(content.strokeOpacity - 0.25) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .square)
        #expect(content.strokeJoin == .bevel)
        #expect(content.strokeMiterLimit == 7)
        #expect(content.strokeDashPattern == [5, 5])
        #expect(content.strokeDashOffset == -2)
    }

    @Test func unsupportedOrMalformedInlineStyleIsRejectedBeforeImport() {
        let invalidStyles = [
            "mix-blend-mode: multiply",
            "fill red",
            "fill:",
            ": red",
            "fill: red !important",
            "--brand: red; fill: var(--brand)",
            "display: none",
            "fill: red; stroke-width"
        ]
        for style in invalidStyles {
            let source = "<svg><path d='M0 0 L20 0 L10 20 Z' style='\(style)'/></svg>"
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func simpleStylesheetSelectorsCascadeBySpecificitySourceOrderAndInheritance() throws {
        let cascaded = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg>
              <style type="text/css"><![CDATA[
                path { fill: orange; stroke: black; stroke-width: 2; }
                .art, .alternate { fill: rebeccapurple; stroke: tomato; stroke-width: 4; }
                .art { stroke: steelblue; }
                #hero { fill: cyan; }
              ]]></style>
              <path id="hero" class="art" fill="red" stroke="red"
                    d="M0 0 L20 0 L10 20 Z" />
            </svg>
            """.utf8
        )))
        let cascadedFill = try #require(cascaded.content.fillColor.usingColorSpace(.deviceRGB))
        let cascadedStroke = try #require(cascaded.content.strokeColor.usingColorSpace(.deviceRGB))
        #expect(abs(cascadedFill.redComponent) < 0.001)
        #expect(abs(cascadedFill.greenComponent - 1) < 0.001)
        #expect(abs(cascadedFill.blueComponent - 1) < 0.001)
        #expect(abs(cascadedStroke.redComponent - (70.0 / 255.0)) < 0.001)
        #expect(abs(cascadedStroke.greenComponent - (130.0 / 255.0)) < 0.001)
        #expect(abs(cascadedStroke.blueComponent - (180.0 / 255.0)) < 0.001)
        #expect(cascaded.content.strokeWidth == 4)

        let inherited = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg>
              <style>
                .theme { color: gold; opacity: 50%; }
                path { fill: currentColor; }
              </style>
              <g class="theme">
                <path d="M0 0 L20 0 L10 20 Z" />
              </g>
            </svg>
            """.utf8
        )))
        let inheritedFill = try #require(inherited.content.fillColor.usingColorSpace(.deviceRGB))
        #expect(abs(inheritedFill.redComponent - 1) < 0.001)
        #expect(abs(inheritedFill.greenComponent - (215.0 / 255.0)) < 0.001)
        #expect(abs(inheritedFill.blueComponent) < 0.001)
        #expect(abs(inherited.content.fillOpacity - 0.5) < 0.001)
    }

    @Test func unsupportedStylesheetsAndUnresolvedClassesAreRejectedBeforeImport() {
        let invalidDocuments = [
            "<svg><style>path:hover { fill: red; }</style><path d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style>.art path { fill: red; }</style><path class='art' d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style>@media (dark-mode) { path { fill: red; } }</style><path d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style>.art { fill: red !important; }</style><path class='art' d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style>.art { mix-blend-mode: multiply; }</style><path class='art' d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style>.art { fill: red;</style><path class='art' d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><path class='external-style' d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style>.known { fill: red; }</style><path class='unknown' d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><style type='text/less'>path { fill: red; }</style><path d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<svg><link href='theme.css'/><path d='M0 0 L20 0 L10 20 Z'/></svg>",
            "<?xml-stylesheet href='theme.css'?><svg><path d='M0 0 L20 0 L10 20 Z'/></svg>"
        ]
        for source in invalidDocuments {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func explicitInheritResolvesTheWholeInheritedPresentationFamily() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg fill="#33669980" fill-opacity="0.8" fill-rule="evenodd"
                 stroke="#f05020" stroke-opacity="0.75" stroke-width="4"
                 stroke-linecap="square" stroke-linejoin="bevel" stroke-miterlimit="7"
                 stroke-dasharray="5" stroke-dashoffset="-2">
              <g fill="inherit" fill-opacity="inherit" fill-rule="inherit"
                 stroke="inherit" stroke-opacity="inherit" stroke-width="inherit"
                 stroke-linecap="inherit" stroke-linejoin="inherit"
                 stroke-miterlimit="inherit" stroke-dasharray="inherit"
                 stroke-dashoffset="inherit">
                <path fill="inherit" fill-opacity="inherit" fill-rule="inherit"
                      stroke="inherit" stroke-opacity="inherit" stroke-width="inherit"
                      stroke-linecap="inherit" stroke-linejoin="inherit"
                      stroke-miterlimit="inherit" stroke-dasharray="inherit"
                      stroke-dashoffset="inherit"
                      d="M0 0 L30 0 L30 30 L0 30 Z M10 10 L20 10 L20 20 L10 20 Z" />
              </g>
            </svg>
            """.utf8
        )))
        let content = imported.content
        let fill = try #require(content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(content.allEditablePathSubpaths.count == 2)
        #expect(abs(fill.redComponent - 0.2) < 0.001)
        #expect(abs(fill.greenComponent - 0.4) < 0.001)
        #expect(abs(fill.blueComponent - 0.6) < 0.001)
        #expect(abs(content.fillOpacity - (128.0 / 255.0 * 0.8)) < 0.001)
        #expect(abs(stroke.redComponent - (240.0 / 255.0)) < 0.001)
        #expect(abs(stroke.greenComponent - (80.0 / 255.0)) < 0.001)
        #expect(abs(stroke.blueComponent - (32.0 / 255.0)) < 0.001)
        #expect(abs(content.strokeOpacity - 0.75) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .square)
        #expect(content.strokeJoin == .bevel)
        #expect(content.strokeMiterLimit == 7)
        #expect(content.strokeDashPattern == [5, 5])
        #expect(content.strokeDashOffset == -2)
    }

    @Test func explicitPaintInheritFallsBackToSVGInitialValues() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg>
              <path d="M0 0 L20 0 L10 20 Z" fill="inherit" stroke="inherit" />
            </svg>
            """.utf8
        )))
        let fill = try #require(imported.content.fillColor.usingColorSpace(.deviceRGB))

        #expect(fill.redComponent == 0)
        #expect(fill.greenComponent == 0)
        #expect(fill.blueComponent == 0)
        #expect(imported.content.fillOpacity == 1)
        #expect(imported.content.strokeOpacity == 0)
    }

    @Test func singleRoundedRectangleImportsAsNativeEditableRectangle() throws {
        let data = Data(
            """
            <svg width="240" height="120" viewBox="0 0 120 60">
              <g opacity="0.5" fill="#336699" stroke="rgba(240, 80, 32, 0.8)"
                 stroke-width="2" stroke-linejoin="bevel" stroke-dasharray="3">
                <rect x="10" y="5" width="50" height="20" rx="4" />
              </g>
            </svg>
            """.utf8
        )

        let imported = try #require(XomoEditableSVGImporter.parse(data))
        let content = imported.content

        #expect(content.kind == .rectangle)
        #expect(imported.size == CGSize(width: 104, height: 44))
        #expect(content.cornerRadius == 8)
        #expect(content.cornerRadii == nil)
        #expect(content.cornerSmoothing == 0)
        #expect(content.fillOpacity == 0.5)
        #expect(abs(content.strokeOpacity - 0.4) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokePosition == .center)
        #expect(content.strokeJoin == .bevel)
        #expect(content.strokeDashPattern == [6, 6])
    }

    @Test func rectanglesThatCannotStayNativeAreRejectedBeforeImport() {
        let unsupported = [
            "<svg><rect width='20' height='10' rx='4' ry='2'/></svg>",
            "<svg><rect width='20' height='10' rx='-1'/></svg>",
            "<svg><rect width='0' height='10'/></svg>",
            "<svg><rect width='20' height='10' pathLength='100'/></svg>",
            "<svg><rect width='20' height='10' fill='none' stroke='black' stroke-width='11'/></svg>",
            "<svg><rect width='20' height='10' fill='none' stroke='none'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func singleCircleAndEllipseImportAsNativeEditableEllipses() throws {
        let circle = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="120" height="80" viewBox="0 0 60 40">
              <g opacity="0.5" fill="#336699" stroke="rgba(240, 80, 32, 0.8)"
                 stroke-width="2" stroke-dasharray="3">
                <circle cx="20" cy="20" r="10" />
              </g>
            </svg>
            """.utf8
        )))
        #expect(circle.content.kind == .ellipse)
        #expect(circle.size == CGSize(width: 44, height: 44))
        #expect(circle.content.fillOpacity == 0.5)
        #expect(abs(circle.content.strokeOpacity - 0.4) < 0.001)
        #expect(circle.content.strokeWidth == 4)
        #expect(circle.content.strokePosition == .center)
        #expect(circle.content.strokeDashPattern == [6, 6])

        let ellipse = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><ellipse cx='14' cy='8' rx='12' ry='6' fill='blue'/></svg>".utf8
        )))
        #expect(ellipse.content.kind == .ellipse)
        #expect(ellipse.size == CGSize(width: 24, height: 12))
        #expect(ellipse.content.fillOpacity == 1)
        #expect(ellipse.content.strokeOpacity == 0)
    }

    @Test func ellipsesThatCannotStayNativeAreRejectedBeforeImport() {
        let unsupported = [
            "<svg><circle r='0'/></svg>",
            "<svg><circle r='-1'/></svg>",
            "<svg><circle r='10' pathLength='100'/></svg>",
            "<svg><ellipse rx='10'/></svg>",
            "<svg><ellipse rx='10' ry='0'/></svg>",
            "<svg><ellipse rx='10' ry='5' fill='none' stroke='black' stroke-width='11'/></svg>",
            "<svg><ellipse rx='10' ry='5' fill='none' stroke='none'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func singleLineImportsAsNativeEditableOpenPath() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="120" height="80" viewBox="0 0 60 40">
              <g opacity="0.5" fill="red" stroke="rgba(32, 80, 240, 0.8)"
                 stroke-width="2" stroke-linecap="square" stroke-dasharray="3">
                <line x1="10" y1="5" x2="30" y2="15" />
              </g>
            </svg>
            """.utf8
        )))
        let content = imported.content

        #expect(content.kind == .path)
        #expect(!content.isPathClosed)
        #expect(abs(imported.size.width - 45.366_563) < 0.001)
        #expect(abs(imported.size.height - 25.366_563) < 0.001)
        let points = content.editablePathAnchors.map(\.point)
        #expect(points.count == 2)
        #expect(abs(points[0].x - 2.683_282) < 0.001)
        #expect(abs(points[0].y - 2.683_282) < 0.001)
        #expect(abs(points[1].x - 42.683_282) < 0.001)
        #expect(abs(points[1].y - 22.683_282) < 0.001)
        #expect(content.fillOpacity == 0)
        #expect(abs(content.strokeOpacity - 0.4) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .square)
        #expect(content.strokeDashPattern == [6, 6])
    }

    @Test func linesWithoutAnExactVisibleStrokeAreRejected() throws {
        let unsupported = [
            "<svg><line x1='0' y1='0' x2='10' y2='10'/></svg>",
            "<svg><line x1='0' y1='0' x2='10' y2='10' stroke='black' pathLength='100'/></svg>",
            "<svg><line x1='10%' y1='0' x2='10' y2='10' stroke='black'/></svg>",
            "<svg><line x1='0' y1='0' x2='10' y2='10' stroke='black' stroke-width='0.05'/></svg>",
            "<svg><line x1='5' y1='5' x2='5' y2='5' stroke='black'/></svg>"
        ]
        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }

        let roundPoint = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><line x1='5' y1='5' x2='5' y2='5' stroke='black' stroke-width='2' stroke-linecap='round'/></svg>".utf8
        )))
        #expect(abs(roundPoint.size.width - 2) < 0.000_001)
        #expect(abs(roundPoint.size.height - 2) < 0.000_001)
        let roundPoints = roundPoint.content.editablePathAnchors.map(\.point)
        #expect(roundPoints.count == 2)
        #expect(roundPoints.allSatisfy {
            abs($0.x - 1) < 0.000_001 && abs($0.y - 1) < 0.000_001
        })

        let minimumVertical = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><line x1='5' y1='0' x2='5' y2='10' stroke='black' stroke-width='0.1'/></svg>".utf8
        )))
        #expect(abs(minimumVertical.size.width - 1) < 0.000_001)
        #expect(abs(minimumVertical.size.height - 10) < 0.000_001)
        #expect(minimumVertical.content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 0.5, y: 0),
            CGPoint(x: 0.5, y: 10)
        ])
    }

    @Test func singlePolylineImportsAsNativeEditableOpenPath() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="120" height="80" viewBox="0 0 60 40">
              <g opacity="0.5" fill="none" stroke="rgba(32, 80, 240, 0.8)"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                 stroke-dasharray="3 2">
                <polyline points="1e1,5 30,5 30,3e1" />
              </g>
            </svg>
            """.utf8
        )))
        let content = imported.content

        #expect(content.kind == .path)
        #expect(!content.isPathClosed)
        #expect(imported.size == CGSize(width: 44, height: 54))
        #expect(content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 42, y: 2),
            CGPoint(x: 42, y: 52)
        ])
        #expect(content.fillOpacity == 0)
        #expect(abs(content.strokeOpacity - 0.4) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .round)
        #expect(content.strokeJoin == .round)
        #expect(content.strokeDashPattern == [6, 4])

        let zeroAreaFill = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><polyline points='0,0 10,10 20,20' stroke='black'/></svg>".utf8
        )))
        #expect(zeroAreaFill.content.fillOpacity == 0)
        #expect(zeroAreaFill.content.editablePathAnchors.count == 3)
    }

    @Test func polylinesThatCannotStayNativeAreRejectedBeforeImport() {
        let unsupported = [
            "<svg><polyline fill='none' stroke='black'/></svg>",
            "<svg><polyline points='0,0' fill='none' stroke='black'/></svg>",
            "<svg><polyline points='0,0 10' fill='none' stroke='black'/></svg>",
            "<svg><polyline points='0,,0 10,10' fill='none' stroke='black'/></svg>",
            "<svg><polyline points='0,0 10%,10' fill='none' stroke='black'/></svg>",
            "<svg><polyline points='0,0 10,10' fill='none' stroke='black' pathLength='100'/></svg>",
            "<svg><polyline points='0,0 10,0 5,10' stroke='black'/></svg>",
            "<svg><polyline points='0,0 10,10' fill='none'/></svg>",
            "<svg><polyline points='0,0 10,10' fill='none' stroke='black' stroke-width='0.05'/></svg>",
            "<svg><polyline points='5,5 5,5' fill='none' stroke='black'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func singlePolygonImportsAsNativeEditableClosedPath() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="120" height="80" viewBox="0 0 60 40">
              <g opacity="0.5" fill="rgba(32, 80, 240, 0.8)"
                 stroke="rgba(240, 80, 32, 0.6)" stroke-width="2"
                 stroke-linejoin="round" stroke-dasharray="3 2">
                <polygon points="10,5 30,5 20,25" />
              </g>
            </svg>
            """.utf8
        )))
        let content = imported.content
        let points = content.editablePathAnchors.map(\.point)

        #expect(content.kind == .path)
        #expect(content.isPathClosed)
        #expect(points.count == 3)
        #expect(abs((points[1].x - points[0].x) - 40) < 0.001)
        #expect(abs(points[1].y - points[0].y) < 0.001)
        #expect(abs((points[2].x - points[0].x) - 20) < 0.001)
        #expect(abs((points[2].y - points[0].y) - 40) < 0.001)
        #expect(imported.size.width > 40)
        #expect(imported.size.height > 40)
        #expect(abs(content.fillOpacity - 0.4) < 0.001)
        #expect(abs(content.strokeOpacity - 0.3) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeJoin == .round)
        #expect(content.strokeDashPattern == [6, 4])

        let evenOdd = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><polygon points='0,0 20,20 0,20 20,0' fill='red' fill-rule='evenodd'/></svg>".utf8
        )))
        #expect(evenOdd.content.isPathClosed)
        #expect(evenOdd.content.fillOpacity == 1)
        #expect(evenOdd.content.strokeOpacity == 0)
        #expect(evenOdd.size == CGSize(width: 20, height: 20))

        let sharpMiter = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><polygon points='0,10 10,0 20,10' fill='none' stroke='black' stroke-width='4' stroke-linejoin='miter' stroke-miterlimit='10'/></svg>".utf8
        )))
        #expect(sharpMiter.content.strokeJoin == .miter)
        #expect(sharpMiter.size.width > 24)
    }

    @Test func polygonsThatCannotStayNativeAreRejectedBeforeImport() {
        let unsupported = [
            "<svg><polygon fill='red'/></svg>",
            "<svg><polygon points='0,0 10,10' fill='none' stroke='black'/></svg>",
            "<svg><polygon points='0,0 10,0 5' fill='red'/></svg>",
            "<svg><polygon points='0,,0 10,0 5,10' fill='red'/></svg>",
            "<svg><polygon points='0,0 10%,0 5,10' fill='red'/></svg>",
            "<svg><polygon points='0,0 10,0 5,10' fill='red' pathLength='100'/></svg>",
            "<svg><polygon points='0,0 10,0 5,10' fill='none' stroke='none'/></svg>",
            "<svg><polygon points='0,0 10,10 20,20' fill='red'/></svg>",
            "<svg><polygon points='0,0 20,20 0,20 20,0' fill='red'/></svg>",
            "<svg><polygon points='0,0 10,0 5,10' fill='red' fill-rule='banana'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func viewportScalingAndFillRulesNeverSilentlyChangeEditableGeometry() throws {
        let scaled = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="200" height="100" viewBox="0 0 100 50">
              <path d="M0 0 L20 0" fill="none" stroke="black" stroke-width="2" />
            </svg>
            """.utf8
        )))
        #expect(scaled.size == CGSize(width: 40, height: 4))
        #expect(scaled.content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 0, y: 2),
            CGPoint(x: 40, y: 2)
        ])
        #expect(scaled.content.strokeWidth == 4)

        let simpleNonzero = XomoEditableSVGImporter.parse(Data(
            "<svg><path d='M0 0 L20 0 L10 10 Z'/></svg>".utf8
        ))
        #expect(simpleNonzero != nil)

        let incompatible = [
            "<svg width='200' height='120' viewBox='0 0 100 100'><path d='M0 0 L20 0' fill='none' stroke='black'/></svg>",
            "<svg><path d='M0 0 C10 0 10 10 20 10 Z'/></svg>",
            "<svg><path d='M0 0 L20 20 L0 20 L20 0 Z'/></svg>"
        ]
        for source in incompatible {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func pathSquareCapsUseTheirExactDiagonalVisualBounds() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg>
              <path d="M 10 5 L 30 15" fill="none" stroke="black"
                    stroke-width="4" stroke-linecap="square" />
            </svg>
            """.utf8
        )))
        let points = imported.content.editablePathAnchors.map(\.point)

        #expect(abs(imported.size.width - 25.366_563) < 0.001)
        #expect(abs(imported.size.height - 15.366_563) < 0.001)
        #expect(points.count == 2)
        #expect(abs(points[0].x - 2.683_282) < 0.001)
        #expect(abs(points[0].y - 2.683_282) < 0.001)
        #expect(abs((points[1].x - points[0].x) - 20) < 0.001)
        #expect(abs((points[1].y - points[0].y) - 10) < 0.001)
    }

    @Test func closedPathMiterJoinsAreNotClippedByHalfStrokePadding() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg>
              <path d="M 0 10 L 10 0 L 20 10 Z" fill="none" stroke="black"
                    stroke-width="4" stroke-linejoin="miter" stroke-miterlimit="10" />
            </svg>
            """.utf8
        )))

        #expect(imported.content.isPathClosed)
        #expect(imported.content.strokeJoin == .miter)
        #expect(imported.size.width > 24)
        #expect(imported.content.editablePathAnchors.allSatisfy { anchor in
            anchor.point.x >= 0 && anchor.point.x <= imported.size.width
                && anchor.point.y >= 0 && anchor.point.y <= imported.size.height
        })
    }

    @Test func pathVisualBoundsKeepBezierControlGeometryEditable() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg>
              <path d="M 0 0 C 100 100 -100 100 20 0"
                    fill="none" stroke="black" stroke-width="2" />
            </svg>
            """.utf8
        )))
        let anchors = imported.content.editablePathAnchors
        let first = try #require(anchors.first)
        let last = try #require(anchors.last)
        let outgoing = try #require(first.outControl)
        let incoming = try #require(last.inControl)

        #expect(abs((outgoing.x - first.point.x) - 100) < 0.001)
        #expect(abs((outgoing.y - first.point.y) - 100) < 0.001)
        #expect(abs((incoming.x - last.point.x) + 120) < 0.001)
        #expect(abs((incoming.y - last.point.y) - 100) < 0.001)
        #expect([first.point, outgoing, incoming, last.point].allSatisfy { point in
            point.x >= 0 && point.x <= imported.size.width
                && point.y >= 0 && point.y <= imported.size.height
        })
    }

    @Test func importingEditableSVGPathIsOneUndoableLayerTransaction() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-import",
            image: NSImage.transparent(size: CGSize(width: 200, height: 120))
        ) { _ in }
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let data = Data(
            """
            <svg xmlns="http://www.w3.org/2000/svg">
              <path d="M 10 20 L 50 40" fill="none" stroke="#123456"
                    stroke-width="4" stroke-linecap="round" />
            </svg>
            """.utf8
        )

        #expect(viewModel.importEditableSVGLayer(data, sourceName: "Connector.svg"))
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        let layer = try #require(viewModel.document.layers.last)
        let content = try #require(layer.shapeContent)
        #expect(layer.name == "Connector")
        #expect(abs(layer.frame.midX - 100) < 0.001)
        #expect(abs(layer.frame.midY - 60) < 0.001)
        #expect(abs(layer.frame.width - 44) < 0.002)
        #expect(abs(layer.frame.height - 24) < 0.002)
        let points = content.editablePathAnchors.map(\.point)
        #expect(points.count == 2)
        #expect(abs((points[1].x - points[0].x) - 40) < 0.001)
        #expect(abs((points[1].y - points[0].y) - 20) < 0.001)
        #expect(!content.isPathClosed)
        #expect(content.fillOpacity == 0)
        #expect(viewModel.document.selectedLayerID == layer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.editableSVGImported", "Connector"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history.count == originalHistoryCount)
    }

    @Test func invalidSVGDoesNotMutateDocumentOrHistory() {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-rejection",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistory = viewModel.document.history
        let originalSelectedLayerID = viewModel.document.selectedLayerID
        let originalSelectedLayerIDs = viewModel.document.selectedLayerIDs

        #expect(!viewModel.importEditableSVGLayer(
            Data("<svg><polygon points='0,0 10,0 5'/></svg>".utf8),
            sourceName: "unsupported.svg"
        ))
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.document.selectedLayerID == originalSelectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == originalSelectedLayerIDs)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.editableSVGImportFailed"))
    }

    @Test func exportedSinglePathCanReturnAsEditableSVGShape() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-roundtrip",
            image: NSImage.transparent(size: CGSize(width: 180, height: 120))
        ) { _ in }
        let anchors = [
            ImageEditorPathAnchor(
                point: CGPoint(x: 0, y: 20),
                inControl: CGPoint(x: 0, y: 40),
                outControl: CGPoint(x: 20, y: 0)
            ),
            ImageEditorPathAnchor(
                point: CGPoint(x: 60, y: 20),
                inControl: CGPoint(x: 40, y: 0)
            ),
            ImageEditorPathAnchor(
                point: CGPoint(x: 30, y: 60),
                outControl: CGPoint(x: 10, y: 60)
            )
        ]
        var layer = ImageEditorLayer.shape(
            name: "Roundtrip Path",
            frame: CGRect(x: 30, y: 20, width: 60, height: 60),
            content: ImageEditorShapeContent(
                kind: .path,
                fillColor: NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 1),
                fillOpacity: 0.7,
                strokeColor: .white,
                strokeWidth: 3,
                strokeOpacity: 0.6,
                strokePosition: .center,
                strokeCap: .round,
                strokeJoin: .bevel,
                strokeDashPattern: [6, 3],
                pathPoints: anchors.map(\.point),
                pathAnchors: anchors,
                isPathClosed: true
            )
        )
        layer.opacity = 0.5
        viewModel.document.layers.append(layer)

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let imported = try #require(XomoEditableSVGImporter.parse(data))
        let restored = imported.content
        let fill = try #require(restored.fillColor.usingColorSpace(.deviceRGB))

        #expect(restored.isPathClosed)
        #expect(restored.editablePathAnchors.count == 3)
        #expect(restored.strokeCap == .round)
        #expect(restored.strokeJoin == .bevel)
        #expect(restored.strokeDashPattern == [6, 3])
        #expect(abs(restored.fillOpacity - 0.35) < 0.001)
        #expect(abs(restored.strokeOpacity - 0.3) < 0.001)
        #expect(abs(fill.blueComponent - 0.8) < 0.01)
        let restoredFirst = try #require(restored.editablePathAnchors.first)
        let restoredLast = try #require(restored.editablePathAnchors.last)
        let restoredIncoming = try #require(restoredFirst.inControl)
        let restoredOutgoing = try #require(restoredLast.outControl)
        #expect(abs(restoredIncoming.x - restoredFirst.point.x) < 0.001)
        #expect(abs((restoredIncoming.y - restoredFirst.point.y) - 20) < 0.001)
        #expect(abs((restoredOutgoing.x - restoredLast.point.x) + 20) < 0.001)
        #expect(abs(restoredOutgoing.y - restoredLast.point.y) < 0.001)
    }

    @Test func exportedPlainRectangleCanReturnAsNativeRectangle() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-rectangle-roundtrip",
            image: NSImage.transparent(size: CGSize(width: 180, height: 120))
        ) { _ in }
        var layer = ImageEditorLayer.shape(
            name: "Card",
            frame: CGRect(x: 30, y: 20, width: 100, height: 60),
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 1),
                fillOpacity: 0.7,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 0.6,
                strokePosition: .center
            )
        )
        layer.opacity = 0.5
        viewModel.document.layers.append(layer)

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let imported = try #require(XomoEditableSVGImporter.parse(data))

        #expect(imported.content.kind == .rectangle)
        #expect(imported.size == CGSize(width: 100, height: 60))
        #expect(imported.content.cornerRadius == 0)
        #expect(imported.content.strokeWidth == 2)
        #expect(abs(imported.content.fillOpacity - 0.35) < 0.001)
        #expect(abs(imported.content.strokeOpacity - 0.3) < 0.001)
    }

    @Test func exportedEllipseCanReturnAsNativeEllipse() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-ellipse-roundtrip",
            image: NSImage.transparent(size: CGSize(width: 180, height: 120))
        ) { _ in }
        var layer = ImageEditorLayer.shape(
            name: "Badge",
            frame: CGRect(x: 30, y: 20, width: 100, height: 60),
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: NSColor(deviceRed: 0.8, green: 0.3, blue: 0.2, alpha: 1),
                fillOpacity: 0.7,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 0.6,
                strokePosition: .center
            )
        )
        layer.opacity = 0.5
        viewModel.document.layers.append(layer)

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let imported = try #require(XomoEditableSVGImporter.parse(data))

        #expect(imported.content.kind == .ellipse)
        #expect(imported.size == CGSize(width: 100, height: 60))
        #expect(imported.content.strokeWidth == 2)
        #expect(abs(imported.content.fillOpacity - 0.35) < 0.001)
        #expect(abs(imported.content.strokeOpacity - 0.3) < 0.001)
    }

    @Test func fileImportPanelRoutesSVGToEditableShapeImporter() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorImport.swift"),
            encoding: .utf8
        )
        let chooserStart = try #require(source.range(of: "func chooseImageLayerFile()"))
        let chooserEnd = try #require(
            source[chooserStart.upperBound...].range(of: "func importEditableSVGLayer")
        )
        let chooser = source[chooserStart.lowerBound..<chooserEnd.lowerBound]

        #expect(chooser.contains("UTType(filenameExtension: \"svg\")"))
        #expect(chooser.contains("url.pathExtension.lowercased() == \"svg\""))
        #expect(chooser.contains("importEditableSVGLayer(data, sourceName: url.lastPathComponent)"))
        let svgRoute = try #require(chooser.range(of: "url.pathExtension.lowercased() == \"svg\""))
        let bitmapRoute = try #require(chooser.range(of: "NSImage(contentsOf: url)"))
        #expect(svgRoute.lowerBound < bitmapRoute.lowerBound)
    }
}
