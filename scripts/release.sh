#!/usr/bin/env bash
# =============================================================================
# release.sh — 象墨 (Xomo / veilpic) Developer ID 打包 + 公证 + DMG 一键脚本
#
# 流程：
#   1. xcodebuild archive（Release + Developer ID 签名）
#   2. 从 archive 导出 .app（method=developer-id）
#   3. 用 create-dmg 或 hdiutil 打包成 .dmg
#   4. 签名 dmg（dmg 本身也要签，否则 Gatekeeper 会拦）
#   5. notarytool 提交公证并同步等待结果
#   6. stapler 把公证票钉到 dmg 上
#   7. spctl 自检
#
# 公证凭据：用 `xcrun notarytool store-credentials` 提前存进 Keychain
#   下面 NOTARY_PROFILE 引用的就是那个 profile 名。
#   首次使用前请先跑一次：
#     xcrun notarytool store-credentials "qingtu-notary" \
#       --apple-id "你的 Apple ID" \
#       --team-id  "ZH2S7D6PL6" \
#       --password "App 专用密码"
#
# 用法:
#   scripts/release.sh                  # 用默认配置打当前版本
#   scripts/release.sh --skip-notarize  # 只签名打包，不公证（本地快速验证用）
# =============================================================================

set -euo pipefail

# ----- 配置区（按需修改） ----------------------------------------------------
SCHEME="veilpic"                                         # xcodebuild scheme
CONFIGURATION="Release"
PROJECT_FILE="veilpic.xcodeproj"
PRODUCT_NAME="Xomo"                                   # 最终 .app / .dmg 文件名
BUNDLE_ID="im.some.xomo"
TEAM_ID="ZH2S7D6PL6"                                     # Developer Team ID
SIGNING_IDENTITY="Developer ID Application: Beijing Alibaba information Technology Co., Ltd. (ZH2S7D6PL6)"
NOTARY_PROFILE="qingtu-notary"                           # store-credentials 时取的名字
DMG_VOLUME_NAME="Xomo"

# ----- 路径 ----------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/release"
ARCHIVE_PATH="${BUILD_DIR}/${PRODUCT_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"
APP_PATH="${EXPORT_DIR}/${PRODUCT_NAME}.app"

# ----- 解析参数 -------------------------------------------------------------
SKIP_NOTARIZE=0
for arg in "$@"; do
  case "$arg" in
    --skip-notarize) SKIP_NOTARIZE=1 ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "未知参数: $arg"; exit 1 ;;
  esac
done

# ----- 读版本号（从 pbxproj 抓 MARKETING_VERSION 的第一个值）---------------
VERSION="$(grep -m 1 'MARKETING_VERSION' "${ROOT_DIR}/${PROJECT_FILE}/project.pbxproj" \
  | sed -E 's/.*MARKETING_VERSION = "?([^";]+)"?;/\1/' | tr -d ' ')"
if [[ -z "$VERSION" ]]; then
  echo "❌ 没能从 pbxproj 抓到 MARKETING_VERSION"
  exit 1
fi
DMG_PATH="${BUILD_DIR}/${PRODUCT_NAME}-${VERSION}.dmg"

echo "========================================="
echo "  ${PRODUCT_NAME} v${VERSION} Release"
echo "  Team:        ${TEAM_ID}"
echo "  Identity:    ${SIGNING_IDENTITY}"
echo "  Notarize:    $([[ $SKIP_NOTARIZE == 1 ]] && echo skip || echo yes)"
echo "  Output:      ${DMG_PATH}"
echo "========================================="

# ----- 检查证书 -------------------------------------------------------------
if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
  echo "❌ 钥匙串里找不到 Developer ID 证书："
  echo "    ${SIGNING_IDENTITY}"
  echo "  请到 Apple Developer → Certificates 下载 .cer 后双击导入"
  exit 1
fi

# ----- 清理上次产物 ---------------------------------------------------------
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$EXPORT_DIR"

# ----- Step 1: archive ------------------------------------------------------
echo ""
echo "[1/7] xcodebuild archive ..."
xcodebuild \
  -project "${ROOT_DIR}/${PROJECT_FILE}" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

# ----- Step 2: 导出 .app（developer-id distribution） -----------------------
echo ""
echo "[2/7] xcodebuild -exportArchive ..."
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
EOF

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ 导出失败，找不到 $APP_PATH"
  exit 1
fi

# ----- Step 3: 打包 DMG -----------------------------------------------------
echo ""
echo "[3/7] 打包 DMG ..."
if command -v create-dmg >/dev/null 2>&1; then
  # 拖拽安装页面：背景图可选，没设的话用纯白
  create-dmg \
    --volname "$DMG_VOLUME_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${PRODUCT_NAME}.app" 150 180 \
    --app-drop-link 450 180 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"
else
  echo "  · 未检测到 create-dmg，回落到 hdiutil（素面 dmg）"
  echo "  · 想要拖拽安装页面：brew install create-dmg"
  TMP_DMG_SRC="${BUILD_DIR}/dmg-src"
  rm -rf "$TMP_DMG_SRC"
  mkdir -p "$TMP_DMG_SRC"
  cp -R "$APP_PATH" "$TMP_DMG_SRC/"
  ln -s /Applications "$TMP_DMG_SRC/Applications"
  hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$TMP_DMG_SRC" \
    -ov -format UDZO \
    "$DMG_PATH"
fi

# ----- Step 4: 签名 DMG -----------------------------------------------------
# 不签名的 dmg 公证会通过，但用户从浏览器下载后 Gatekeeper 仍会因为
# "下载附加 quarantine 属性 + dmg 自身未签名" 而弹警告。签了才完整。
echo ""
echo "[4/7] codesign DMG ..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose "$DMG_PATH"

# ----- Step 5: 公证 ---------------------------------------------------------
if [[ $SKIP_NOTARIZE == 1 ]]; then
  echo ""
  echo "[5/7] --skip-notarize 已跳过公证"
  echo "      产物：$DMG_PATH"
  echo "      ⚠️ 这份 dmg 用户下载后 Gatekeeper 会拦，仅限本地验证用"
  exit 0
fi

echo ""
echo "[5/7] notarytool submit ..."
echo "      提交后会同步等待 Apple 审核（通常 2-15 分钟）"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ----- Step 6: stapler ------------------------------------------------------
echo ""
echo "[6/7] stapler staple ..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# ----- Step 7: Gatekeeper 自检 ----------------------------------------------
echo ""
echo "[7/7] spctl 自检 ..."
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH" || true

echo ""
echo "✅ 完成"
echo "   DMG: $DMG_PATH"
echo "   版本: $VERSION"
echo "   提示：把这份 dmg 上传到 GitHub Releases 或对象存储即可对外分发。"
