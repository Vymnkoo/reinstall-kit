# Vymnkoo's reinstall kit

Puts a whole Arch Linux setup back on a fresh install: caelestia + Hyprland, all
the programs, the configs, fonts, and the fixes found along the way
(NVIDIA, Windows clock, Ardour realtime, Spotify key, ...).

> [!IMPORTANT]
> This repo was originally a private repo for my personal Linux installation and not meant for public installation. but if u want to install this, go ahead (:

**Online wiki:** https://vymnkoo-wiki.infinityfree.me

More detail on every part: open **`wiki/index.html`** in a browser (works offline,
even on the fresh install before setup.sh). How it all works, step by step:
[docs/how-it-works.md](docs/how-it-works.md).

A reinstall takes **3 steps**:

1. **Install plain Arch** with `archinstall` (about 15 min), using the checklist below
2. **Get this kit** and run `bash setup.sh` (20–60 min, mostly waiting)
3. **Reboot.** Then do the few things on the "still to do" list it shows you

> Not yet run on a real fresh install: only tested with `--dry-run`. Keep the setup
> log from the first real run so problems can be fixed.

---

## Keep the kit up to date (on the working PC)

After you install new programs or change settings, run:

```
bash ~/reinstall-kit/kit-update.sh
```

It only **copies into** the kit and never changes your PC. It:
- saves your configs, caelestia settings, VSCodium extensions, HyprMod and
  the `update-all` command (updates pacman + AUR + flatpak + uv tools in one go)
- adds programs you installed since last time to `packages/apps.txt`
- keeps a history of every save (git), so an older version can be brought back
- uploads it to GitHub, and makes a spare copy on a second drive if one is mounted
- runs the private add-on's own update too, if it's on this PC (see below)

---

## Step 1 – archinstall checklist

Boot the Arch USB stick (Rufus, "ISO Image" mode, GPT/UEFI). Connect to the
internet (`iwctl` for Wi-Fi, Ethernet just works). Type `archinstall` and set:

| Menu | Pick |
|---|---|
| Mirrors | your region |
| Locales | keyboard `us`, language `en_US.UTF-8` |
| **Disk configuration** | see below ⚠️ |
| Swap | **zram: yes** |
| Bootloader | **GRUB** |
| Hostname | a name for the PC |
| Root password | leave empty (sudo user is enough) |
| **User account** | your username, **superuser: yes** |
| **Profile** | Desktop → **Hyprland** (gives you a login screen + terminal) |
| ↳ Graphics driver | NVIDIA RTX 20xx/GTX 16xx or newer → **Nvidia (open kernel module)**. AMD / Intel → **open-source** |
| Audio | **pipewire** |
| Kernels | `linux` |
| Network | **NetworkManager** |
| Additional packages | `git` |
| **Optional repositories** | **multilib** (setup.sh turns it on too, if you forget) |
| Timezone | your timezone |

### ⚠️ Disk configuration (the only scary part)

**Dual-boot with Windows**: pick *Manual partitioning* and change only the two
Linux partitions:

| Partition | Size | Set to |
|---|---|---|
| Linux boot | about 1 GiB | **format, fat32, mount `/boot`** |
| Linux root | the rest | **format, ext4, mount `/`** |

**Do not touch the Windows partitions** (Windows, its boot partition, data drives).
If you're unsure which is which, stop and check before continuing.

**A PC that only runs Linux**: *Use a best-effort default layout* → ext4 is fine.
It wipes that whole disk.

Then pick **Install**, wait, choose **Reboot**, and pull out the USB stick.

---

## Step 2 – run the kit

1. Log in. You'll see a plain Hyprland desktop. Press **Super+Q** to open a terminal (kitty).
2. Get the kit into your home folder. The repo is public, so no login is needed:
   ```
   git clone https://github.com/Vymnkoo/reinstall-kit ~/reinstall-kit
   ```
   (or copy the folder from a USB stick / backup drive to `~/reinstall-kit`)
3. Run it:
   ```
   bash ~/reinstall-kit/setup.sh
   ```
4. Type your password when asked (it doesn't show while typing). A menu
   appears. **Space** ticks or unticks, **Enter** starts:

   ```
   ┌──────────── Vymnkoo's reinstall kit ────────────┐
   │ [*] apps      Everyday apps (Zen, Discord, ...)  │
   │ [*] gaming    Gaming (Steam, Heroic, osu!, ...)  │
   │ [*] creative  Music + video (Ardour + fix)       │
   │ [*] dev       Coding (VSCodium, Java, Claude)    │
   │ [*] dualboot  Dual-boot with Windows             │
   └──────────────────────────────────────────────────┘
   ```
5. Wait. It goes through 9 steps and shows ✔ for each thing that worked.
   Around step 5 **the desktop changes its look**. That's Caelestia arriving,
   and it's normal.

If something fails (internet drops, AUR is down), just **run it again**. It
skips everything that's already done.

Want to see what it would do without changing anything? `bash setup.sh --dry-run`

---

## Step 3 – reboot + finish

```
reboot
```

At the end, setup.sh prints a **"still to do by hand"** list (also saved in
`~/reinstall-kit-report.txt`). Usually that's:

- **DaVinci Resolve**: download the Linux zip into ~/Downloads, then
  `bash ~/reinstall-kit/extras/davinci-resolve/install-resolve.sh`
- **Spotify theme**, if it didn't apply: open Spotify once, log in, close it, then `spicetify backup apply`
- **Angsana New** (Thai font): copy it from Windows' font folder

---

## Private add-on

Personal parts (wallpapers, this PC's extra drive, disk notes, server hosting)
live in a separate **private** repo, `reinstall-kit-private`. After setup.sh:

```
sudo pacman -S github-cli
gh auth login        # GitHub.com → HTTPS → Yes → Login with a web browser
gh repo clone Vymnkoo/reinstall-kit-private ~/reinstall-kit-private
bash ~/reinstall-kit-private/private-setup.sh
```

The kit works fine without it.

---

## What's in the kit

```
reinstall-kit/
├── README.md            ← this guide
├── wiki/index.html      ← the wiki (open it in a browser)
├── docs/how-it-works.md ← how setup.sh and kit-update.sh work
├── setup.sh             ← the installer (step 2)
├── kit-update.sh        ← saves the working PC into the kit
├── packages/            ← lists of programs, one file per menu choice
│   ├── core.txt tools.txt apps.txt gaming.txt creative.txt dev.txt
│   ├── hw-*.txt cpu-*.txt   (drivers, picked automatically)
│   └── _not-in-kit.txt _archinstall.txt   (never installed by setup.sh)
├── configs/
│   ├── home/            ← your saved configs and fonts (copied to ~)
│   ├── files.txt        ← which configs get saved (add lines here)
│   └── caelestia-components.txt, vscodium-extensions.txt, uv-tools.txt
├── system/fstab-extra.txt   ← extra drives to mount (example only)
└── extras/davinci-resolve/  ← Resolve build recipe + installer
```

To add or remove a program, edit the right file in `packages/` (one name per line).
To keep something installed on this PC out of the kit (e.g. OBS, which you can get from
Bazaar), put it in `packages/_not-in-kit.txt` so kit-update.sh stops adding it.
