# Transsion Flagship 16

Magisk / KernelSU module for **Transsion OS 16** (XOS, HiOS, iTel OS) on Infinix, Tecno, and itel devices.

Unlock GT-tier features, customize boot/reboot animations and system sounds, and tune animations & blur — all from the built-in WebUI.

## Requirements

- Root: **Magisk 20400+** or **KernelSU** with WebUI support
- Transsion device running **OS 16**
- Do **not** run alongside **Transsion Flagship 15** (Flagship 16 disables it on install)

Optional: **Mountify** or similar if you use `/tr_product` overlays (not bundled).

## Installation

1. Download `TransFlagship16_V2.3.zip` from [Releases](https://github.com/Just-LilG/TRANSSION-FLAGSHIP/releases)
2. Flash in Magisk / KernelSU Manager
3. Reboot
4. Open the module **WebUI** → configure → **Apply & Save** → reboot when prompted

## Features (verified on Infinix X6886 / G99)

| Feature | Status |
|---------|--------|
| Boot & reboot animation packs | Working |
| System sounds (Pixel / Huawei / iOS / S25 charging, etc.) | Working |
| AI Suite (subtitles, call summary, notes, writing, VEE) | Working |
| Gaming (eSports touch, bypass charge, GT triggers in XArena) | Working |
| Magellan 144Hz picker (always on) + optional Force 120Hz | Working |
| Always-on Display (AOD) | Working |
| Super volume | Working |
| Parallel animations + flagship blur (off leaves stock blur) | Working |
| Social Turbo / Unlock extras / Outdoor boost / Air Transfer | Keys applied *(may already exist on stock)* |

## Known limitations

Device-dependent — tested primarily on **Infinix X6886 (G99, XOS 16)**:

- **Display HDR** — props may stick but the Settings row may not appear on some G99 builds.
- **Cute Pet** — feature flags apply; UI may not unhide on G99.
- **AI Gallery Art / Studio** — menus may show; full editor requires GT hardware/software not on G99.
- **Status bar overlay** — upload your own APK in the WebUI (no bundled iOS/XOS pack).

Features your phone already had from stock will not look “new” — keys are kept so other OS 16 devices can benefit.

## Blur

**Dynamic blur** is on by default and applies flagship glass (including the notification shade). Turning it **off** restores stock Transsion blur keys. **Parallel** still needs global `ro.tr_animation.platform_level=3` for app open/close; shade glass is kept at stock via SystemUI vconfig (`platform_level=2`) so blur-off does not strip Parallel.

## WebUI tabs

- **Home** — device info, Support (Dump flags, conflict check, boot log)
- **Features** — AI, gaming, social, blur, AOD, display, unlock extras, 120Hz
- **Media** — boot and reboot animation
- **Sounds** — system sounds

## Troubleshooting

- **Apply & Save** writes runtime settings; most props need a **reboot**.
- Use **Dump flags** on the Home → Support section and paste output when reporting issues.
- Boot log: `transflagship16_service.log` and `post_fs_data.log` in the module folder.
- **Module conflicts** — the installer and Home Support section scan other modules that share paths or blur props.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits

**Lil G** ([@Just_LilGXX](https://t.me/Just_LilGXX)) — [TRANSSION-FLAGSHIP](https://github.com/Just-LilG/TRANSSION-FLAGSHIP)
