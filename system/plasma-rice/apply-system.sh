#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  System-wide parts of the Caelestia Blush Plasma rice. setup.sh runs it as:
#      sudo bash system/plasma-rice/apply-system.sh <your-username>
#  Safe to run again. What it does:
#   1. login screen: sddm-astronaut-theme in blush colours + your wallpaper
#   2. login screen runs on KWin (Wayland) with your monitor + mouse settings,
#      so the screen doesn't go black on login and the mouse feels the same
#   3. hides the blinking "_" text-console cursor seen for a moment at login
#  Undo: sudo rm /etc/sddm.conf.d/10-theme.conf /etc/sddm.conf.d/20-wayland.conf
#        and remove vt.global_cursor_default=0 from /etc/kernel/cmdline (or GRUB)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
U="${1:?username}"; H="$(getent passwd "$U" | cut -d: -f6)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME=/usr/share/sddm/themes/sddm-astronaut-theme

# 1. login screen theme
mkdir -p /etc/sddm.conf.d
install -m 644 "$HERE/10-theme.conf" /etc/sddm.conf.d/10-theme.conf
rm -f /etc/sddm.conf.d/10-caelestia-theme.conf   # old name
if [[ -d $THEME ]]; then
  install -m 644 "$HERE/astronaut.conf.user" "$THEME/Themes/astronaut.conf.user"
  # SDDM can't read your home folder, so the wallpaper is copied into the theme.
  WP="$H/Pictures/Wallpapers/wallpaper.jpg"
  [[ -f $WP ]] || WP="$(ls /usr/share/wallpapers/Next/contents/images/*.png 2>/dev/null | head -1)"
  [[ -n $WP ]] && install -m 644 "$WP" "$THEME/Backgrounds/caelestia-blush.jpg"
  echo "login screen theme set"
else echo "sddm-astronaut-theme not installed - login theme skipped"; fi

# 2. greeter on KWin, with your monitor + mouse settings
install -m 644 "$HERE/20-wayland.conf" /etc/sddm.conf.d/20-wayland.conf
SH="$(getent passwd sddm | cut -d: -f6)"; SH="${SH:-/var/lib/sddm}"
install -d -o sddm -g sddm "$SH/.config"
for f in kwinoutputconfig.json kcminputrc; do
  [[ -f $H/.config/$f ]] && install -m 644 -o sddm -g sddm "$H/.config/$f" "$SH/.config/$f"
done
echo "login screen runs on KWin"

# 3. no blinking text-console cursor
P=vt.global_cursor_default=0
if [[ -f /etc/kernel/cmdline ]] && ls /boot/EFI/Linux/*.efi &>/dev/null; then   # boots a UKI
  if ! grep -q "$P" /etc/kernel/cmdline; then
    sed -i "1s/\$/ $P/" /etc/kernel/cmdline && mkinitcpio -P >/dev/null
  fi
  echo "console cursor hidden (UKI)"
elif [[ -f /etc/default/grub ]]; then                                        # GRUB
  grep -q "$P" /etc/default/grub || sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/&$P /" /etc/default/grub
  echo "console cursor hidden (GRUB, applies after the boot menu is rebuilt)"
else echo "unknown boot setup - console cursor left as is"; fi
