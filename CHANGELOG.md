# Changelog

## v3.20
- Fixed OS detection in the WebUI incorrectly labeling HiOS/TECNO devices as XOS. The device-info display now uses the same brand/build-description fallback chain as the installer, instead of hardcoding "XOS" whenever the primary prop was empty.
- Fixed the header subtitle showing a hardcoded, stale version string ("V3.1"). It now reads the live version from `module.prop` on disk.

## v3.19
- Added a "Copy for Support" button on the Home tab that bundles `module.prop`, module enabled/disabled state, and the full service log into one clipboard-ready report — no file explorer needed.
- Renamed and restyled the Service Log section to make it clear it's the first place to check when something isn't working.

## v3.18
- Added a full diagnostic header to the boot-time service log: device model/brand, Android version, raw OS-detection prop values, which detection path was used, SELinux state, and a live spot-check of key props.
- `install.sh` now persists what it detected at flash time to a file that the boot-time log includes, so install-time and boot-time diagnostics are both visible in one place.

## v3.17
- Fixed slow uploads for boot/shutdown animation and emoji font (both write to two destinations): base64 is now decoded once and copied to each destination, instead of being re-decoded from scratch per destination.
- Added staged progress messages during upload (Reading → Encoding → Sending → Writing) instead of a single static "Uploading..." message.

## v3.16 and earlier (this release)
- **Fixed `system.prop` not loading at all** — it was at the zip root instead of `common/system.prop`, so Magisk's installer never picked it up and none of the base props were ever applied.
- **Fixed OS-specific prop appends being silently overwritten** by the installer's own post-install copy step; the base `system.prop` is now extracted before any XOS/HiOS/iTel-specific appends run.
- **Fixed animation levels not persisting correctly** — unlock/recent/launch/blur levels are now static values proven to work on real hardware, instead of being toggleable at runtime (which was unreliable: `ro.*` props are cached at process start, and a bad saved config value could silently break app open/close animation).
- **Fixed toggles not respecting individual sub-features** — turning off "Launch Animation" alone previously did nothing, since only the master switch and level sliders were ever read.
- **Fixed several WebUI toggles being decorative** (collected into config but never applied): boot animation, emoji font, and several AI/social toggles now actually take effect.
- **Fixed boot sound / boot animation / shutdown animation timing** — these are now handled in `post-fs-data.sh` (which runs before the module mounts) instead of `service.sh` (which runs too late for a file-rename toggle to matter that boot).
- **Fixed file uploads silently failing** on anything over ~60–100KB, due to spreading a large byte array into `String.fromCharCode`, which throws past that size. Boot animations, charging videos, and fonts are all larger than this.
- **Fixed a real UI freeze on large uploads** caused by string concatenation on a growing multi-MB string (effectively O(n²) work). Encoding now happens in a Web Worker on a separate thread, with a main-thread fallback for WebViews without Worker support.
- **Fixed uploaded filenames never persisting** across app reloads, due to a key-name mismatch between what the upload handler wrote and what the config loader read.
- **Fixed a race condition** where starting a second upload (or tapping Apply & Save / Reset) while one was still in progress could corrupt the in-progress upload via a shared temp file path.
- **Removed Screenshot Bypass** entirely per user request.
- Charging animation upload now recalculates and patches the MD5 hash pinned in `lockscreen_charge_config.xml`, since the OS may reject a video that doesn't match.
- Added a "Reset to Defaults" option to recover from a bad/stale config without manual editing.
- Replaced native browser `confirm()` popups with a themed in-app modal.
- Added device-name fallback chain (`ro.product.marketname`, etc.) for devices where `ro.product.model` returns empty.
