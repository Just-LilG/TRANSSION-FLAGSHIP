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

## XOS 16 (beta)

XOS 16 support is new and marked **BETA** in the WebUI (amber badge on Home, XOS 16 devices only). Animation, blur, and dynamic-bar props for XOS 16 are unverified across the wider device pool — everything else in the module is stable. If you're on XOS 16 and notice glitches after enabling animation/blur features, disable them and report it.

On XOS 16, three settings default to **off** on a fresh install (existing configs are never overwritten): Charging Animation, Fingerprint Animation, and the Signal/WiFi status bar overlay (now has a "None" option). You can re-enable any of them manually.

**Note:** this build does not bundle or auto-install a metamodule (e.g. Mountify). If you want one, install it separately before flashing.

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
