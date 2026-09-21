#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
dist_dir="$project_root/dist"
app_path="$dist_dir/TuckBar.app"
dmg_path="$dist_dir/TuckBar-0.9.8.dmg"
vol_name="TuckBar"
tmp_dir=$(mktemp -d)

trap 'rm -rf "$tmp_dir"' EXIT

if [[ ! -d "$app_path" ]]; then
  echo "❌ TuckBar.app 不存在，请先执行 package-stable.sh"
  exit 1
fi

echo "📦 正在准备 DMG 内容..."
rm -f "$dmg_path"
mkdir -p "$tmp_dir/dmg_root"
cp -R "$app_path" "$tmp_dir/dmg_root/"
ln -s /Applications "$tmp_dir/dmg_root/Applications"

echo "💿 正在生成原生 DMG 安装镜像..."
hdiutil create -volname "$vol_name" \
  -srcfolder "$tmp_dir/dmg_root" \
  -ov -format UDZO \
  "$dmg_path"

echo "✅ DMG 安装镜像已成功生成: $dmg_path"
