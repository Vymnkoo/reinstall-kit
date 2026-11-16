# Changelog

- **2.0.0-alpha** (2026-11-16) – Kit split in two. This repo is now public (clone with no login); personal parts moved to a private add-on repo: wallpapers, the extra-drive mount line, disk notes and the server-hosting option (the old `network` menu choice). Ardour project list and plugin scan log no longer saved.
- **1.2.4-alpha** (2026-11-16) – `--dry-run` now shows every command it skips; before, the font refresh, Spotify theme, wallpaper, sleep masking and GRUB rebuild showed ✔ with no `[dry-run]` line.
- **1.2.3-alpha** (2026-11-16) – Bedrock client (bedrock-on-linux-bin) added to apps.txt. New packages/_not-in-kit.txt for programs left out on purpose (OBS: get it from Bazaar).
- **1.2.2-alpha** (2026-11-16) – How-it-works doc added as `docs/how-it-works.md` (GitHub shows it as a page); README links to it.
- **1.2.1-alpha** (2026-11-16) – Kit wiki added as `wiki/index.html` (open it in a browser, works offline); README links to it.
- **1.2.0-alpha** (2026-11-16) – Kit saves the audio-boot-log script + its user service, and setup.sh switches it on at login. Airwindows + Vital moved to creative.txt.
- **1.1.0-alpha** (2026-11-16) – Kit now saves and restores the `update-all` command (~/.local/bin/update-all). Its PATH line lives in caelestia/user-config.fish so caelestia updates can't wipe it.
- **1.0.1-alpha** (2026-11-15) – Kit lives in a private GitHub repo; kit-update.sh uploads after each save; README explains cloning it on a new PC.
- **1.0.0-alpha** (2026-11-15) – First version: setup.sh (menu, 9 steps, dry-run, retry-safe), kit-update.sh (saves configs/packages, git history, spare copy on D:), package groups, archinstall checklist, DaVinci Resolve helper. Dry-run tested on the working PC only; not yet run on a fresh install.
