#!/usr/bin/env bash
# Builds two .deb variants with distinct Package IDs/Names, since one package
# layout can't serve both, and a repo needs distinct Package IDs to list both
# as separate entries instead of colliding:
#   - rootful:  classic /Library/MobileSubstrate/DynamicLibraries — iOS 12-16-era
#               jailbreaks (checkra1n, unc0ver, Taurine, Odyssey, Chimera, palera1n
#               "rootful" mode, ...).
#   - rootless: /var/jb-prefixed layout — Dopamine, palera1n rootless mode.
set -euo pipefail
cd "$(dirname "$0")"

: "${THEOS:?THEOS environment variable must be set (e.g. export THEOS=~/theos)}"

echo "==> Building rootful package..."
cp control.rootful control
rm -rf .theos packages
make package
for f in packages/*.deb; do
  mv "$f" "${f%.deb}-rootful.deb"
done

echo "==> Building rootless package..."
cp control.rootless control
rm -rf .theos
THEOS_PACKAGE_SCHEME=rootless make package
for f in packages/*.deb; do
  case "$f" in
    *-rootful.deb) ;; # already renamed above, skip
    *) mv "$f" "${f%.deb}-rootless.deb" ;;
  esac
done

rm -f control

echo "==> Done:"
ls -la packages/
