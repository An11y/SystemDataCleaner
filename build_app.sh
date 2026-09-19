#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

INSTALL_APPS=1
MAKE_DIST=0
NO_INSTALL=0

for arg in "$@"; do
  case "$arg" in
    --no-install) NO_INSTALL=1; INSTALL_APPS=0 ;;
    --package|--dist) MAKE_DIST=1; INSTALL_APPS=0 ;;
    --install) INSTALL_APPS=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./build_app.sh [--no-install] [--package]

  (default)     собрать .app и поставить в /Applications
  --no-install  только локальный SystemDataCleaner.app
  --package     ZIP (+ DMG) в dist/ для GitHub Releases
EOF
      exit 0
      ;;
  esac
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/SystemDataCleaner/Info.plist" 2>/dev/null || echo "1.0")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/SystemDataCleaner/Info.plist" 2>/dev/null || echo "1")"
APP_NAME="System Data Cleaner"
BUNDLE_ID="com.an11y.SystemDataCleaner"
DIST_NAME="System-Data-Cleaner-${VERSION}-macOS"

sign_app() {
  local target="$1"
  # Один и тот же identity → Full Disk Access не слетает при обновлении.
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "  ⚠ adhoc-подпись (FDA может слетать при следующей сборке)"
    codesign --force --deep --sign - "$target" 2>/dev/null || true
  else
    codesign --force --deep \
      --sign "$SIGN_IDENTITY" \
      --identifier "$BUNDLE_ID" \
      "$target"
  fi
}

echo "→ Сборка release (universal arm64 + x86_64)…"
swift build -c release --arch arm64
swift build -c release --arch x86_64

BIN_ARM="$ROOT/.build/arm64-apple-macosx/release/SystemDataCleaner"
BIN_X86="$ROOT/.build/x86_64-apple-macosx/release/SystemDataCleaner"
BIN_OUT="$ROOT/.build/SystemDataCleaner-universal"

if [[ -x "$BIN_ARM" && -x "$BIN_X86" ]]; then
  lipo -create "$BIN_ARM" "$BIN_X86" -output "$BIN_OUT"
  BIN="$BIN_OUT"
  echo "  → universal: $(lipo -archs "$BIN")"
else
  echo "  → одна из arch не собралась, ищу нативный бинарник…"
  BIN="$(find "$ROOT/.build" -path '*/release/SystemDataCleaner' -type f ! -name '*.d' | head -1)"
  [[ -n "$BIN" && -x "$BIN" ]] || { echo "Бинарник не найден"; exit 1; }
  echo "  → $(lipo -archs "$BIN" 2>/dev/null || file "$BIN")"
fi

APP="$ROOT/SystemDataCleaner.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "→ Подпись (стабильный identity для Full Disk Access)…"
chmod +x "$ROOT/scripts/ensure_codesign_identity.sh"
SIGN_IDENTITY="$("$ROOT/scripts/ensure_codesign_identity.sh")"
echo "  → identity: $SIGN_IDENTITY"

echo "→ Иконка…"
mkdir -p "$ROOT/Resources"
swift "$ROOT/scripts/generate_icon.swift" "$ROOT/Resources"

echo "→ Сборка .app…"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN" "$MACOS/SystemDataCleaner"
chmod +x "$MACOS/SystemDataCleaner"
cp "$ROOT/SystemDataCleaner/Info.plist" "$CONTENTS/Info.plist"
echo -n "APPL????" > "$CONTENTS/PkgInfo"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

if [[ -d "$ROOT/packaging/lproj/en.lproj" ]]; then
  ditto "$ROOT/packaging/lproj/en.lproj" "$RESOURCES/en.lproj"
fi
if [[ -d "$ROOT/packaging/lproj/ru.lproj" ]]; then
  ditto "$ROOT/packaging/lproj/ru.lproj" "$RESOURCES/ru.lproj"
fi

sign_app "$APP"

if [[ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
fi

if [[ "$INSTALL_APPS" -eq 1 ]]; then
  DEST="/Applications/${APP_NAME}.app"
  echo "→ Установка в $DEST (без переподписи — сохраняет Full Disk Access)…"
  pkill -x SystemDataCleaner 2>/dev/null || true
  sleep 0.3
  # Перезапись поверх того же пути + тот же signing identity → TCC/FDA остаётся.
  # Не делаем rm -rf и не codesign повторно после ditto.
  mkdir -p "$DEST"
  ditto "$APP" "$DEST"
  if [[ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" 2>/dev/null || true
  fi
  echo "Готово: $DEST"
  echo "Запуск: open -a \"${APP_NAME}\""
fi

if [[ "$MAKE_DIST" -eq 1 ]]; then
  DIST="$ROOT/dist"
  STAGE="$DIST/stage"
  echo "→ Пакет для Releases (v${VERSION}, build ${BUILD})…"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  ditto "$APP" "$STAGE/${APP_NAME}.app"

  ZIP="$DIST/${DIST_NAME}.zip"
  rm -f "$ZIP"
  (
    cd "$STAGE"
    /usr/bin/zip -qry "$ZIP" "${APP_NAME}.app"
  )
  echo "  ZIP: $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"

  DMG="$DIST/${DIST_NAME}.dmg"
  DMG_STAGE="$DIST/dmg-stage"
  rm -rf "$DMG_STAGE" "$DMG"
  mkdir -p "$DMG_STAGE"
  ditto "$STAGE/${APP_NAME}.app" "$DMG_STAGE/${APP_NAME}.app"
  ln -s /Applications "$DMG_STAGE/Applications"
  hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$DMG_STAGE"
  echo "  DMG: $DMG ($(du -h "$DMG" | awk '{print $1}'))"

  shasum -a 256 "$ZIP" "$DMG" | tee "$DIST/SHA256SUMS.txt"
  echo "Готово. Загрузка: gh release create v${VERSION} dist/${DIST_NAME}.zip dist/${DIST_NAME}.dmg --title \"…\" --notes \"…\""
elif [[ "$NO_INSTALL" -eq 1 ]]; then
  echo "Готово: $APP"
  echo "Запуск: open \"$APP\""
fi
