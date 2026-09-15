#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
source_app="$project_root/build-release-stable/Build/Products/Release/MenuBarOrganizer.app"
stable_app="$project_root/dist/MenuBarOrganizer.app"
versioned_archive="$project_root/dist/TuckBar-0.8.2-alpha.zip"
designated_requirement='designated => identifier "com.hanshijiu.MenuBarOrganizer"'
signing_identity="${MENU_BAR_SIGNING_IDENTITY:--}"

cd "$project_root"
xcodegen generate
xcodebuild \
  -project MenuBarOrganizer.xcodeproj \
  -scheme MenuBarOrganizer \
  -configuration Release \
  -derivedDataPath build-release-stable \
  build CODE_SIGNING_ALLOWED=NO

mkdir -p dist
ditto "$source_app" "$stable_app"
mkdir -p "$stable_app/Contents/Resources"
ditto "$project_root/Resources/AppIcon.icns" "$stable_app/Contents/Resources/AppIcon.icns"
if [[ "$signing_identity" == "-" ]]; then
codesign --force --deep --sign - \
  --identifier com.hanshijiu.MenuBarOrganizer \
  --requirements "=$designated_requirement" \
  "$stable_app"
else
  codesign --force --deep --sign "$signing_identity" "$stable_app"
fi

ditto -c -k --sequesterRsrc --keepParent "$stable_app" "$versioned_archive"
codesign --verify --deep --strict "$stable_app"
codesign -d -r- "$stable_app"
