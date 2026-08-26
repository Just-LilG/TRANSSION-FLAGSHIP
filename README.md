# Transsion Flagship — All OS Edition

A Magisk/KernelSU module for Transsion devices (Infinix, Tecno, itel) running XOS, HiOS, or iTel OS, with a WebUI for customizing sounds, boot/charging animations, status bar style, AI/gaming features, and display/performance tuning — without editing system files by hand.

## What it does

### Sounds
- Boot sound (with custom upload support)
- Wired charging sound
- Wireless charging sound
- Individual system sound customization — keypress, connection, and feedback sounds (25+ sounds, each with its own upload or bundled alternate)

### Media
- Custom FOD (in-display fingerprint) animation styles
- Boot animation style (with custom upload support)
- Shutdown animation style (with custom upload support)
- Charging animation (with custom upload support)
- Custom emoji font

### Visual Effects
- Dynamic blur — dock, folders, recents & app drawer

### AI Suite
- AI subtitles
- AI call summary
- AI notification summary
- AI sound recorder
- AI notes

### Gaming Suite
- eSports touch sensitivity
- Frame interpolation
- Ray tracing
- Game HDR
- Bypass charging (play while charging without battery-health throttling)

### Social Turbo v3
- Call recording
- AI translation
- Beauty & makeup filters

### Display
- DC dimming
- Color enhancement
- HDR display
- Reading mode
- Force 120Hz refresh rate

### Status Bar
- Signal & WiFi icon style — iOS, XOS 16, None, or your own custom overlay

### Navigation & System
- Hide navigation bar
- AOD (Always-On Display)

### Experimental
- Animation & renderer tuning — higher-tier animation model, union renderer, dynamic bar (XOS 16)

### Platform Support
- XOS (15 & 16, with version-specific optimizations)
- HiOS
- iTel OS

### In-App Tools
- **Module Conflict Check** — scans other installed modules for files at the same system paths this one uses, both at install time and on demand from the WebUI, with safe Disable/Remove actions per conflicting module
- Live status panel
- Service log & troubleshooting viewer
- In-app update checker
- Reset to defaults

## Two modules (OS 15 vs OS 16)

Use **one** module. Do not run Flagship 15 and Flagship 16 together.

| Module | Path in this repo | Flash zip | OS |
|---|---|---|---|
| **Transsion Flagship** (this README) | repo root | `TransFlagship_V4.xx.zip` | XOS / HiOS / iTel **15** |
| **Transsion Flagship 16** | [`os16/`](os16/) | `TransFlagship16_V1.xx.zip` | Transsion **OS 16** (XOS / HiOS / iTel) |

Flagship 16 has its own WebUI. Features are added **one at a time** after they are verified on a real OS 16 device. **V1.06 is boot animation + boot sound** (XOS / HiOS 16 / Custom / Off animation; Waltz / Custom / Off sound via tinyplay — zip audio is silent on XOS 16). Installer disables Flagship 15 if it is still active.

See [`os16/CHANGELOG.md`](os16/CHANGELOG.md) for Flagship 16 versions.

## XOS 16 on Flagship 15 (legacy)

The OS 15 module still contains XOS 16 workarounds, but most of those features do not apply correctly on Transsion OS 16. Prefer **Flagship 16** on OS 16 phones.

**Note:** neither module bundles or auto-installs a metamodule (e.g. Mountify). If you want one, install it separately before flashing.

## Requirements

- Root via Magisk (20400+) or KernelSU, with WebUI support
- A Transsion-brand device (Infinix / Tecno / itel) running XOS, HiOS, or iTel OS

## Installation

1. Flash the zip via Magisk Manager or KernelSU Manager
2. Reboot
3. Open the module's WebUI (from your root manager app) to customize

## Notes

- Every customization is applied at boot (`post-fs-data.sh`) or via **Apply & Save** in the WebUI (`service.sh` / runtime props). Some settings — mainly ones baked into `system.prop` — only take effect after a reboot, not a live Apply.
- Two toggles under Features are marked **Experimental**: they're sourced from third-party reference modules, not independently verified on every device, and can require a reboot to fully revert. Read their in-app warnings before enabling.
- Uploading a new custom sound automatically backs up whatever was there before — an "Undo" option appears on the Sounds tab for a short window after any upload.
- See `CHANGELOG.md` for the full version history, including known issues and what's fixed in each release.

## Uninstalling

Standard Magisk/KernelSU module removal. `uninstall.sh` cleans up module-created files; nothing outside the module's own directory is touched.
