#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  kit-update.sh - save THIS PC's current setup into the kit.
#  Run it now and then (e.g. after installing new apps or changing configs):
#      bash ~/reinstall-kit/kit-update.sh
#  It never installs or changes anything on the PC - it only copies INTO the kit.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B=$'\e[1m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'; R=$'\e[0m'
ok()   { echo "  ${GRN}✔${R} $*"; }
warn() { echo "  ${YLW}!${R} $*"; }

echo "${CYN}${B}Saving this PC's setup into the kit...${R}"

# 1. configs listed in configs/files.txt -> configs/home/
DEST="$KIT/configs/home"
rm -rf "$DEST.new"; mkdir -p "$DEST.new"
n=0
while read -r f; do
  [[ -z $f || $f == \#* ]] && continue
  if [[ -e $HOME/$f ]]; then
    mkdir -p "$DEST.new/$(dirname "$f")"
    cp -a "$HOME/$f" "$DEST.new/$f"; n=$((n+1))
  else warn "not found, skipped: ~/$f"; fi
done < "$KIT/configs/files.txt"
rm -rf "$DEST"; mv "$DEST.new" "$DEST"
ok "$n config files/folders saved"

# 2. keep personal/leftover bits out of the public kit: the splash's copy of the
#    wallpaper (wallpapers live in the private add-on) and *.bak / *.save files
rm -f "$DEST/.local/share/plasma/look-and-feel/caelestia.blush.splash/contents/splash/images/background.jpg"
find "$DEST" \( -name '*.bak' -o -name '*.bak-*' -o -name '*.save' \) -delete
ok "wallpaper copy + backup files left out"

# 3. VSCodium extensions
if command -v codium &>/dev/null; then
  codium --list-extensions </dev/null 2>/dev/null | grep -v '^Warning' > "$KIT/configs/vscodium-extensions.txt"
  ok "$(wc -l < "$KIT/configs/vscodium-extensions.txt") VSCodium extensions"
fi

# 4. uv tools (e.g. HyprMod)
{
  echo "# uv tools (setup.sh runs: uv tool install <line>)"
  for r in "$HOME"/.local/share/uv/tools/*/uv-receipt.toml; do
    [[ -f $r ]] || continue
    git="$(grep -o 'git = "[^"]*"' "$r" | head -1 | cut -d'"' -f2)"
    if [[ -n $git ]]; then echo "git+$git"; else basename "$(dirname "$r")"; fi
  done
} > "$KIT/configs/uv-tools.txt"
ok "uv tools: $(grep -vc '^#' "$KIT/configs/uv-tools.txt")"

# 5. DaVinci Resolve recipe (the PKGBUILD we bumped by hand)
RES="$HOME/Projects/aur/davinci-resolve"
if [[ -f $RES/PKGBUILD ]]; then
  cp "$RES"/{PKGBUILD,*.install,*.sh} "$KIT/extras/davinci-resolve/" 2>/dev/null
  ok "DaVinci Resolve PKGBUILD ($(grep -m1 '^pkgver=' "$RES/PKGBUILD"))"
fi

# 6. packages: anything new that isn't in a list yet?
# the private add-on's lists count as known too, so its packages don't land in apps.txt
PRIVATE="${KIT_PRIVATE:-$HOME/reinstall-kit-private}"
KNOWN="$(cat "$KIT"/packages/*.txt "$PRIVATE"/packages/*.txt 2>/dev/null | grep -vE '^\s*(#|$)' | sed 's/^flatpak://' | sort -u)"
IGNORE="paru-bin paru-bin-debug davinci-resolve os-prober kwin-effect-rounded-corners-git"
# installed outside pacman on this PC (setup.sh gets it from the AUR), so never "gone"
HAND_INSTALLED="klassy"
NEW=()
while read -r p; do
  grep -qx "$p" <<<"$KNOWN" && continue
  [[ " $IGNORE " == *" $p "* ]] && continue
  NEW+=("$p")
done < <(pacman -Qqe; flatpak list --app --columns=application 2>/dev/null)
GONE=()
while read -r p; do
  [[ " $HAND_INSTALLED " == *" $p "* ]] && continue
  pacman -Qq "$p" &>/dev/null && continue
  flatpak info "$p" &>/dev/null && continue
  GONE+=("$p")
done < <(cat "$KIT"/packages/{core,rice,tools,apps,gaming,creative,dev}.txt | grep -vE '^\s*(#|$)' | sed 's/^flatpak://')

if ((${#NEW[@]})); then
  echo
  echo "${YLW}${B}New programs that aren't in the kit yet:${R} ${NEW[*]}"
  echo "  They were added to ${B}packages/apps.txt${R} so a reinstall gets them."
  echo "  (Move a line to gaming.txt / dev.txt / ... if it fits better.)"
  for p in "${NEW[@]}"; do
    if flatpak info "$p" &>/dev/null; then echo "flatpak:$p"; else echo "$p"; fi
  done >> "$KIT/packages/apps.txt"
fi
if ((${#GONE[@]})); then
  echo
  echo "${YLW}${B}In the kit but not installed here any more:${R} ${GONE[*]}"
  echo "  If you removed them on purpose, delete their lines from the files in packages/."
  echo "  (Drivers for other hardware are fine to keep.)"
fi

# 7. history (git) + a spare copy on D:
if [[ -d $KIT/.git ]] && command -v git &>/dev/null; then
  git -C "$KIT" add -A
  if git -C "$KIT" diff --cached --quiet; then ok "no changes since last save"
  else git -C "$KIT" commit -qm "kit-update $(date '+%Y-%m-%d %H:%M')" && ok "saved a new version (git)"; fi
  # upload to GitHub, if a remote is set up
  if git -C "$KIT" remote get-url origin &>/dev/null; then
    if [[ -n "$(git -C "$KIT" log --oneline '@{u}..' 2>/dev/null)" ]] || ! git -C "$KIT" rev-parse '@{u}' &>/dev/null; then
      if git -C "$KIT" push -q -u origin HEAD 2>/dev/null; then ok "uploaded to GitHub"
      else warn "could not upload to GitHub (no internet, or not logged in: run  gh auth login)"; fi
    else ok "GitHub copy already up to date"; fi
  fi
fi
if mountpoint -q /mnt/d 2>/dev/null && [[ -w /mnt/d ]]; then
  rm -rf /mnt/d/ReinstallKit.new && cp -a "$KIT" /mnt/d/ReinstallKit.new &&
  rm -rf /mnt/d/ReinstallKit && mv /mnt/d/ReinstallKit.new /mnt/d/ReinstallKit &&
  ok "spare copy on D:\\ReinstallKit"
fi
# 8. the private add-on saves its own parts (wallpapers, ...) into its own repo
if [[ -f $PRIVATE/private-update.sh ]]; then
  echo; echo "${CYN}${B}Private add-on:${R}"
  bash "$PRIVATE/private-update.sh"
fi
echo
echo "${GRN}${B}Kit is up to date.${R}"
