# Transsion Flagship 16

Magisk / KernelSU module for **Transsion OS 16** (XOS, HiOS, iTel OS) on Infinix, Tecno, and itel devices.

Unlock GT-tier features, customize boot/reboot animations and system sounds, and tune animations & blur — all from the built-in WebUI. No manual `build.prop` editing.

## Requirements

- Root: **Magisk 20400+** or **KernelSU** with WebUI support
- Transsion device running **OS 16**
- Do **not** run alongside **Transsion Flagship 15** (Flagship 16 disables it on install)

Optional: **Mountify** or similar if you use `/tr_product` overlays (not bundled).

## Installation

1. Download `TransFlagship16_V2.0.zip` from [Releases](https://github.com/Just-LilG/TRANSSION-FLAGSHIP/releases)
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
| Force 120Hz / 144Hz Magellan picker | Working |
| Always-on Display (AOD) | Working |
| Super volume | Working |
| Parallel animations + blur tiers (default **level 2**) | Working (see limits) |
| Social Turbo / Unlock extras / Outdoor boost / Air Transfer | Keys applied *(may already exist on stock)* |

## Known limitations

Device-dependent — tested primarily on **Infinix X6886 (G99, XOS 16)**:

- **Display HDR** — props may stick but the Settings row may not appear on some G99 builds.
- **Cute Pet** — feature flags apply; UI may not unhide on G99.
- **AI Gallery Art / Studio** — menus may show; full editor requires GT hardware/software not on G99.
- **Blur level 1** — solid notification shade vs Parallel animations tradeoff on some devices; **level 2** is the recommended default.
- **Status bar overlay** — upload your own APK in the WebUI (no bundled iOS/XOS pack).

Features your phone already had from stock will not look “new” — keys are kept so other OS 16 devices can benefit.

## Blur levels

| Level | Behavior |
|-------|----------|
| **1** | Smart-series solid (no dock glass). Shade/Parallel may conflict on some devices. |
| **2** | **Default** — dock/recents blur, solid notification shade on G99. |
| **3** | Full flagship glass (unionrender + compositor). |

## WebUI tabs

- **Home** — device info, feature roadmap, Dump flags, boot log
- **Features** — AI, gaming, social, blur, AOD, display, unlock extras, 120Hz
- **Media** — boot/shutdown animation, charging animation, sounds
- **Status bar** — custom overlay upload

## Troubleshooting

- **Apply & Save** writes runtime settings; most props need a **reboot**.
- Use **Dump flags** on the Home tab and paste output when reporting issues.
- Boot log: `transflagship16_service.log` and `post_fs_data.log` in the module folder.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits

Just-LilG — [TRANSSION-FLAGSHIP](https://github.com/Just-LilG/TRANSSION-FLAGSHIP)
