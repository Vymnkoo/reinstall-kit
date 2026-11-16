#!/usr/bin/env bash
# Builds + installs DaVinci Resolve (free) from the kit's PKGBUILD.
#  1. Download "DaVinci Resolve <version> Linux" (zip) from blackmagicdesign.com
#     into ~/Downloads.
#  2. bash install-resolve.sh
# Needs ~30 GB free space in your home folder while building.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HOME/Projects/aur/davinci-resolve"
VER="$(grep -m1 '^pkgver=' "$HERE/PKGBUILD" | cut -d= -f2)"

ZIP="$(ls -t "$HOME"/Downloads/DaVinci_Resolve_*_Linux*.zip 2>/dev/null | grep -v Studio | head -1 || true)"
[[ -n $ZIP ]] || { echo "No DaVinci_Resolve_..._Linux.zip in ~/Downloads - download it first."; exit 1; }
echo "Zip:            $ZIP"
echo "Kit PKGBUILD is for version $VER"
if [[ $ZIP != *"_${VER}_"* && $ZIP != *"_${VER}."* ]]; then
  echo "!! The zip looks like a different version than $VER."
  echo "   The PKGBUILD's pkgver + sha256sums must be updated first (ask Claude)."
  exit 1
fi

mkdir -p "$BUILD"
cp "$HERE"/{PKGBUILD,davinci-resolve.install,davinci-control-panels-setup.sh} "$BUILD/"
ln -sf "$ZIP" "$BUILD/DaVinci_Resolve_${VER}_Linux.zip"
cd "$BUILD"
rm -rf src pkg            # a half-finished earlier build breaks the next one
# install what the build needs, then build (no sudo) and install
sudo pacman -S --needed --noconfirm libarchive xdg-user-dirs patchelf
PKGEXT='.pkg.tar' makepkg -s -f --noconfirm
sudo pacman -U --noconfirm ./davinci-resolve-"$VER"-*.pkg.tar
echo "DaVinci Resolve $VER installed."
