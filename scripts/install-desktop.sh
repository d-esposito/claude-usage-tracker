#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
install_root="${1:-$HOME/Applications}"
app_bundle="$install_root/Claude Usage Tracker.app"
contents="$app_bundle/Contents"

swift build --package-path "$project_root" -c release

/usr/bin/pkill -x ClaudeUsageTrackerDesktop 2>/dev/null || true
mkdir -p "$contents/MacOS" "$contents/Resources"
cp "$project_root/.build/release/ClaudeUsageTrackerDesktop" "$contents/MacOS/ClaudeUsageTrackerDesktop"
cp "$project_root/DesktopApp/Info.plist" "$contents/Info.plist"
chmod 755 "$contents/MacOS/ClaudeUsageTrackerDesktop"

/usr/bin/codesign --force --deep --sign - "$app_bundle"
/usr/bin/open "$app_bundle"

echo "Installed: $app_bundle"
echo "Use the gauge icon in the menu bar to enable Launch at Login."
