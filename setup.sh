#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Vymnkoo's reinstall kit - setup.sh
#  Turns a fresh Arch install (made with archinstall, see README.md) into the
#  full caelestia desktop with all apps, configs and fixes.
#
#  Run it as your normal user (NOT with sudo), from inside the kit folder:
#      bash setup.sh            do it
#      bash setup.sh --dry-run  only show what it would do, change nothing
#
#  Safe to run again: anything already installed or set is skipped.
# ─────────────────────────────────────────────────────────────────────────────
KIT_VERSION="2.0.0-alpha"
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1
# For testing: KIT_CHOICES="apps dev ..." skips the menu.
KIT_CHOICES="${KIT_CHOICES:-}"

STAMP="$(date +%Y-%m-%d_%H%M)"
LOG="$HOME/reinstall-kit-setup_$STAMP.log"
[[ "${1:-}" == "--dry-run" ]] && LOG="${TMPDIR:-/tmp}/reinstall-kit-dryrun_$STAMP.log"
CFG_BACKUP="$HOME/.reinstall-kit-backups/$STAMP"
FAILED_PKGS=()   # packages that would not install
PROBLEMS=()      # things that went wrong
TODO=()          # things the user still has to do by hand

# ── look ────────────────────────────────────────────────────────────────────
B=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'; R=$'\e[0m'
STEP_NO=0; STEP_TOTAL=9
step()  { STEP_NO=$((STEP_NO+1)); echo; echo "${CYN}${B}━━━ Step $STEP_NO/$STEP_TOTAL: $* ━━━${R}"; }
ok()    { echo "  ${GRN}✔${R} $*"; }
info()  { echo "  ${DIM}•${R} $*"; }
warn()  { echo "  ${YLW}!${R} $*"; }
problem(){ echo "  ${RED}✘${R} $*"; PROBLEMS+=("$*"); }
die()   { echo "${RED}${B}✘ $*${R}"; exit 1; }

# run / srun: every command that CHANGES something goes through these,
# so --dry-run can print instead of doing. The dry-run line goes to fd 3 (the
# screen + log), so it still shows when the call itself is sent to /dev/null.
exec 3>&1
run()  { if ((DRY)); then echo "  ${DIM}[dry-run]${R} $*" >&3; else "$@"; fi; }
srun() { if ((DRY)); then echo "  ${DIM}[dry-run] sudo${R} $*" >&3; else sudo "$@"; fi; }

# read a package list: drop comments/blank lines; flatpak: lines go elsewhere
pkgs_of()     { grep -vE '^\s*(#|$)' "$KIT/packages/$1.txt" | grep -v '^flatpak:' ; }
flatpaks_of() { grep '^flatpak:' "$KIT/packages/$1.txt" | sed 's/^flatpak://' ; }
installed()   { pacman -Qq "$1" &>/dev/null; }

# install packages with paru (handles both normal and AUR packages).
# Whole list in one go first; if that fails, one by one so one broken
# package can't stop the rest.
install_pkgs() {
  local want=() p
  for p in "$@"; do installed "$p" || want+=("$p"); done
  if ((${#want[@]} == 0)); then ok "already installed"; return; fi
  info "installing ${#want[@]}: ${want[*]}"
  local PARU=(paru -S --needed --noconfirm --skipreview --sudoloop)
  if run "${PARU[@]}" "${want[@]}"; then ok "done"; return; fi
  warn "one of them failed - trying them one by one"
  for p in "${want[@]}"; do
    installed "$p" && continue
    run "${PARU[@]}" "$p" || { problem "could not install $p"; FAILED_PKGS+=("$p"); }
  done
}

# ── 0. checks ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Don't run this with sudo. Run:  bash setup.sh   (it asks for your password itself)"
[[ -f /etc/arch-release ]] || die "This only works on Arch Linux."
curl -fsI --max-time 10 https://archlinux.org >/dev/null || die "No internet. Connect to Wi-Fi/Ethernet first (nmtui), then try again."

echo "${CYN}${B}Vymnkoo's reinstall kit $KIT_VERSION${R}"
((DRY)) && echo "${YLW}${B}DRY RUN - nothing will be changed.${R}"
echo "Your password is needed for installing. It won't show while you type - that's normal."
if ! ((DRY)); then
  sudo -v || die "Wrong password or no sudo rights."
  # keep sudo alive while the script runs
  ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
fi

if [[ -z $KIT_CHOICES ]] && ! command -v whiptail &>/dev/null; then
  info "installing the menu tool (libnewt)..."
  sudo pacman -S --needed --noconfirm libnewt >/dev/null || die "Could not install libnewt."
fi

# ── detect hardware ─────────────────────────────────────────────────────────
GPU_LINES="$(lspci -nn | grep -Ei 'vga|3d|display' || true)"
HW_GROUPS=()
grep -q '\[10de:' <<<"$GPU_LINES" && HW_GROUPS+=(hw-nvidia)
grep -q '\[1002:' <<<"$GPU_LINES" && HW_GROUPS+=(hw-amd)
grep -q '\[8086:' <<<"$GPU_LINES" && HW_GROUPS+=(hw-intel)
grep -q AuthenticAMD /proc/cpuinfo && HW_GROUPS+=(cpu-amd)
grep -q GenuineIntel /proc/cpuinfo && HW_GROUPS+=(cpu-intel)
OLD_NVIDIA=0
if grep -q '\[10de:' <<<"$GPU_LINES" && grep -qE 'GTX (9[0-9]{2}|10[0-9]{2})|GT [0-9]{3,4}\b|TITAN X|Quadro [KMP]' <<<"$GPU_LINES"; then
  OLD_NVIDIA=1   # too old for nvidia-open
fi
HAS_WINDOWS=0
lsblk -rno FSTYPE | grep -qx ntfs && HAS_WINDOWS=1

GPU_NAME="$(sed -E 's/^[^:]*: //; s/ \[[0-9a-f]{4}:[0-9a-f]{4}\].*//' <<<"$GPU_LINES" | paste -sd ';')"

# ── menu ────────────────────────────────────────────────────────────────────
onoff() { (( $1 )) && echo ON || echo OFF; }
if [[ -n $KIT_CHOICES ]]; then CHOICES="$(tr ' ' '\n' <<<"$KIT_CHOICES")"; else
CHOICES=$(whiptail --title "Vymnkoo's reinstall kit $KIT_VERSION" --separate-output --checklist \
"Detected graphics: ${GPU_NAME:-unknown}
The desktop (caelestia + Hyprland), drivers and terminal tools are always installed.

Pick the extras.  SPACE = tick/untick,  ENTER = start,  ESC = quit." 20 78 6 \
  apps     "Everyday apps (Zen, Discord, Spotify, OnlyOffice...)"   ON \
  gaming   "Gaming (Steam, Heroic, osu!, Modrinth, Sober)"          ON \
  creative "Music + video (Ardour + realtime audio fix)"            ON \
  dev      "Coding (VSCodium, Zed, Java, Maven, Claude Code)"       ON \
  dualboot "Dual-boot with Windows (boot menu entry, clock fix)"    "$(onoff $HAS_WINDOWS)" \
  3>&1 1>&2 2>&3) || { echo "Cancelled - nothing was changed."; exit 0; }
fi
want() { grep -qx "$1" <<<"$CHOICES"; }

SUMMARY="This will install:
  • desktop: caelestia + Hyprland and your configs
  • drivers: ${HW_GROUPS[*]:-none detected}
  • extras:  $(echo $CHOICES)

It takes about 20-60 minutes depending on internet speed.
Your current configs are backed up first. Start?"
[[ -n $KIT_CHOICES ]] || whiptail --title "Ready" --yesno "$SUMMARY" 16 72 || { echo "Cancelled - nothing was changed."; exit 0; }

# from here on, everything is also written to the log file
exec > >(tee -a "$LOG") 2>&1
exec 3>&1   # fd 3 follows stdout into the log too
echo "kit $KIT_VERSION  started $(date)  choices: $(echo $CHOICES)  hw: ${HW_GROUPS[*]}"
STEP_TOTAL=9

# ── 1. system update + pacman settings ──────────────────────────────────────
step "Updating the system"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  info "turning on the multilib repo (needed for Steam and 32-bit drivers)"
  srun sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi
grep -q '^Color' /etc/pacman.conf || srun sed -i 's/^#Color/Color/' /etc/pacman.conf
srun pacman -Syu --needed --noconfirm base-devel git || problem "system update had errors (see log)"
ok "system up to date"

# ── 2. paru (installs AUR packages) ─────────────────────────────────────────
step "Getting paru (the AUR helper)"
if command -v paru &>/dev/null; then ok "already there"
elif ((DRY)); then echo "  ${DIM}[dry-run]${R} build + install paru-bin from the AUR"
else
  TMPB="$(mktemp -d)"
  if run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$TMPB/paru-bin" &&
     ( cd "$TMPB/paru-bin" && run makepkg -si --noconfirm ); then ok "paru installed"
  else die "Could not install paru - check internet and run setup.sh again."; fi
  rm -rf "$TMPB"
fi

# ── 3. drivers ──────────────────────────────────────────────────────────────
step "Graphics + CPU drivers"
for g in "${HW_GROUPS[@]}"; do
  if [[ $g == hw-nvidia ]] && ((OLD_NVIDIA)); then
    warn "This NVIDIA card is too old for nvidia-open - skipped."
    TODO+=("Old NVIDIA card: install the legacy driver by hand (Arch wiki 'NVIDIA' page).")
    continue
  fi
  info "$g"; mapfile -t L < <(pkgs_of "$g"); install_pkgs "${L[@]}"
done

# ── 4. apps ─────────────────────────────────────────────────────────────────
step "Installing your programs"
# Spotify's signing key: the normal keyserver is often unreachable here, so fetch it from Spotify.
if want apps && ! gpg --list-keys 5384CE82BA52C83A &>/dev/null; then
  info "importing Spotify's signing key"
  run bash -c 'curl -fsSL https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg | gpg --import -' \
    || problem "could not import Spotify's key (Spotify may fail to build)"
fi
GROUPS_TO_INSTALL=(core tools)
for g in apps gaming creative dev; do want "$g" && GROUPS_TO_INSTALL+=("$g"); done
want dualboot && EXTRA_DUALBOOT=(os-prober) || EXTRA_DUALBOOT=()
for g in "${GROUPS_TO_INSTALL[@]}"; do
  echo "  ${B}$g${R}"; mapfile -t L < <(pkgs_of "$g"); install_pkgs "${L[@]}"
done
((${#EXTRA_DUALBOOT[@]})) && { echo "  ${B}dualboot${R}"; install_pkgs "${EXTRA_DUALBOOT[@]}"; }

# spicetify needs to write into Spotify's folder
if [[ -d /opt/spotify ]]; then
  srun chmod a+wr /opt/spotify && srun chmod -R a+wr /opt/spotify/Apps
  [[ -f $HOME/.config/spotify/prefs ]] || { run mkdir -p "$HOME/.config/spotify"; run touch "$HOME/.config/spotify/prefs"; }
fi

# ── 5. caelestia ────────────────────────────────────────────────────────────
step "Installing caelestia (shell + its configs)"
install_pkgs caelestia-cli
# the optional caelestia parts you use, minus the ones for groups you didn't pick
OPTIONAL=()
while read -r c; do
  case "$c" in
    spotify|discord|todoist|zen) want apps || continue ;;
    vscodium|vscode|zed)         want dev  || continue ;;
  esac
  OPTIONAL+=("$c")
done < <(grep -vE '^\s*(#|$)' "$KIT/configs/caelestia-components.txt")
ENABLE="$(IFS=,; echo "${OPTIONAL[*]}")"
info "components: default + $ENABLE"
run caelestia install --aur-helper paru --enable-components "$ENABLE" --noconfirm \
  || problem "caelestia install reported an error (see log)"

# ── 6. your configs ─────────────────────────────────────────────────────────
step "Putting back your own configs"
SRC="$KIT/configs/home"
if [[ -d $SRC ]]; then
  CHANGED=0; SAME=0
  while read -r f; do
    f="${f#./}"
    if cmp -s "$SRC/$f" "$HOME/$f"; then SAME=$((SAME+1)); continue; fi
    CHANGED=$((CHANGED+1))
    ((DRY)) && { echo "  ${DIM}[dry-run]${R} would put back ~/$f"; continue; }
    if [[ -e $HOME/$f ]]; then mkdir -p "$CFG_BACKUP/$(dirname "$f")"; cp -a "$HOME/$f" "$CFG_BACKUP/$f"; fi
    mkdir -p "$HOME/$(dirname "$f")"
    cp -a "$SRC/$f" "$HOME/$f"
  done < <(cd "$SRC" && find . -type f)
  ok "$CHANGED files put back, $SAME already the same"
  ((CHANGED && !DRY)) && info "the old versions are saved in $CFG_BACKUP"
else warn "no saved configs in the kit (run kit-update.sh on a working PC first)"; fi
# HyprMod's settings file only loads if hyprland.lua asks for it
HL="$HOME/.config/hypr/hyprland.lua"
if [[ -f $HOME/.config/hypr/hyprland-gui.lua && -f $HL ]] && ! grep -q 'require("hyprland-gui")' "$HL"; then
  run bash -c "printf '\n-- HyprMod managed settings\nrequire(\"hyprland-gui\")\n' >> '$HL'"
  ok "HyprMod settings hooked into Hyprland"
fi
run fc-cache -f >/dev/null && ok "fonts refreshed"
# user services that came back with the configs (e.g. audio-boot-log) - switch them on
for svc in "$HOME"/.config/systemd/user/*.service; do
  [[ -f $svc ]] || continue
  grep -q '^WantedBy=default.target' "$svc" || continue
  run mkdir -p "$HOME/.config/systemd/user/default.target.wants"
  run ln -sf "$svc" "$HOME/.config/systemd/user/default.target.wants/$(basename "$svc")" && ok "$(basename "$svc" .service) runs at login"
done

# ── 7. extra tools ──────────────────────────────────────────────────────────
step "Extra tools"
while read -r t; do
  [[ -z $t || $t == \#* ]] && continue
  name="$(basename "${t%.git}")"
  if [[ -d $HOME/.local/share/uv/tools/$name ]]; then ok "$name already there"
  else run uv tool install "$t" </dev/null && ok "$name" || problem "could not install $name ($t)"; fi
done < "$KIT/configs/uv-tools.txt"

FLATPAKS=()
for g in "${GROUPS_TO_INSTALL[@]}"; do mapfile -t -O "${#FLATPAKS[@]}" FLATPAKS < <(flatpaks_of "$g"); done
if ((${#FLATPAKS[@]})); then
  run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  for fp in "${FLATPAKS[@]}"; do
    flatpak info "$fp" &>/dev/null && { ok "$fp already there"; continue; }
    run sudo flatpak install -y --noninteractive flathub "$fp" && ok "$fp" || problem "could not install flatpak $fp"
  done
fi

if want dev; then
  if command -v claude &>/dev/null || [[ -x $HOME/.local/bin/claude ]]; then ok "Claude Code already there"
  else run bash -c 'curl -fsSL https://claude.ai/install.sh | bash' && ok "Claude Code" || problem "Claude Code install failed"; fi
  if command -v codium &>/dev/null; then
    HAVE="$(codium --list-extensions 2>/dev/null)"
    while read -r e; do
      [[ -z $e || $e == \#* ]] && continue
      grep -qix "$e" <<<"$HAVE" && continue
      run codium --install-extension "$e" </dev/null >/dev/null 2>&1 && ok "VSCodium: $e" || warn "VSCodium extension $e not installed"
    done < "$KIT/configs/vscodium-extensions.txt"
  fi
fi

if [[ -d /opt/spotify ]] && command -v spicetify &>/dev/null; then
  run spicetify backup apply >/dev/null 2>&1 || run spicetify apply >/dev/null 2>&1 \
    && ok "Spotify theme applied" \
    || TODO+=("Spotify theme: open Spotify once, log in, close it, then run:  spicetify backup apply")
fi

# ── 8. system settings ──────────────────────────────────────────────────────
step "System settings"
for s in NetworkManager bluetooth sddm; do
  systemctl is-enabled "$s" &>/dev/null || { srun systemctl enable "$s" && ok "enabled $s"; }
done
systemctl is-enabled fstrim.timer &>/dev/null || { srun systemctl enable fstrim.timer && ok "SSD trim weekly"; }

# extra drives (e.g. D:) - only the ones that exist on this PC
while read -r line; do
  [[ -z $line || $line == \#* ]] && continue
  uuid="$(awk '{print $1}' <<<"$line" | sed 's/^UUID=//')"; mnt="$(awk '{print $2}' <<<"$line")"
  [[ -e /dev/disk/by-uuid/$uuid ]] || continue
  if grep -q "$uuid" /etc/fstab; then ok "drive $mnt already in fstab"; continue; fi
  srun mkdir -p "$mnt"
  srun bash -c "echo '$line' >> /etc/fstab" && ok "drive $mnt will mount at boot"
  srun systemctl daemon-reload </dev/null; srun mount "$mnt" </dev/null || warn "could not mount $mnt now (it will try at next boot)"
done < "$KIT/system/fstab-extra.txt"

if want dualboot; then
  if [[ -f /etc/default/grub ]] && ! grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then
    srun sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub || ((DRY)) || srun bash -c 'echo GRUB_DISABLE_OS_PROBER=false >> /etc/default/grub'
    ok "boot menu will look for Windows"
  else ok "boot menu already looks for Windows"
  fi
  # Windows keeps the hardware clock in local time; match it so the clock isn't 7 h off
  if [[ "$(timedatectl show -p LocalRTC --value)" == yes ]]; then ok "clock already matches Windows"
  else srun timedatectl set-local-rtc 1 && ok "clock fixed for Windows"; fi
fi

if want creative; then
  if id -nG | grep -qw realtime; then ok "you're already in 'realtime' (Ardour fix)"
  else srun usermod -aG realtime "$USER" && ok "added you to 'realtime' (Ardour won't get killed)"; fi
fi

# ── 9. boot menu ────────────────────────────────────────────────────────────
step "Updating the boot menu"
if installed grub && [[ -f /etc/default/grub ]]; then
  srun grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 && ok "GRUB menu rebuilt" || problem "grub-mkconfig failed"
  if want dualboot && ! ((DRY)) && ! sudo grep -qi windows /boot/grub/grub.cfg; then
    warn "Windows not found yet - it usually appears after a reboot + running:  sudo grub-mkconfig -o /boot/grub/grub.cfg"
  fi
else info "not using GRUB - skipped"; fi

# ── things that are always manual ───────────────────────────────────────────
want creative && TODO+=("DaVinci Resolve: download the Linux zip from blackmagicdesign.com into ~/Downloads, then run:  bash $KIT/extras/davinci-resolve/install-resolve.sh")
want creative && TODO+=("Ardour: pick the 'JACK/Pipewire' audio system (not ALSA) when it asks.")
# your own private add-on (wallpapers, extra drives, ...), if it's on this PC
[[ -f $HOME/reinstall-kit-private/private-setup.sh ]] && TODO+=("Private add-on: run  bash ~/reinstall-kit-private/private-setup.sh  (add  network  to also set up server hosting)")
TODO+=("Thai font Angsana New: copy angsa*.ttf from Windows (C:\\Windows\\Fonts) into ~/.local/share/fonts, then run  fc-cache -f")

# ── report ──────────────────────────────────────────────────────────────────
REPORT="$HOME/reinstall-kit-report.txt"
make_report() {
  echo "Reinstall kit $KIT_VERSION - finished $(date)"
  echo
  if ((${#PROBLEMS[@]})); then echo "PROBLEMS (${#PROBLEMS[@]}):"; printf '  - %s\n' "${PROBLEMS[@]}"; echo
  else echo "No problems."; echo; fi
  echo "STILL TO DO BY HAND:"; printf '  - %s\n' "${TODO[@]}"
  echo; echo "Full log: $LOG"
}
echo; echo "${CYN}${B}━━━ Report ━━━${R}"
make_report
((DRY)) || make_report > "$REPORT"
echo
if ((${#PROBLEMS[@]})); then echo "${YLW}${B}Done, with ${#PROBLEMS[@]} problem(s) - see above.${R}"
else echo "${GRN}${B}All done!${R}"; fi
((DRY)) || echo "This list is saved in ${B}$REPORT${R}."
echo "${B}Now reboot:${R}  reboot"
