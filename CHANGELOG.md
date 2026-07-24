# Changelog

## v4.0
- **First V4 release.** All explanatory comments removed from every script and the WebUI (shell scripts, `system.prop`, `index.html`, `bridge.js`) per request — code behavior is unchanged, this is a documentation-only cleanup.
- Fixed a stale default: `post-fs-data.sh`'s status bar style fallback still read `"ios"` from before the v3.40 default change to XOS 16; now correctly defaults to `"xos16"`, matching every other default location.

## v3.42
- **Removed the "Camera Sounds" section entirely.** Confirmed these 7 sounds (Burst Shot/camera_click, Video Start/Stop, camera_shutter, and the 3 Timer sounds) can never actually work — `TranssionCamera.apk` bundles its own audio assets internally and never reads the shared system sound path our module writes to. Leaving broken, non-functional pickers visible was misleading, so the section, its 9 sound keys (including Camera_Sequential and camera_focus, which were also camera-app-scoped), and the corresponding gating logic in `post-fs-data.sh` have all been removed. 25 of the original 34 individual sounds remain — all genuinely functional via the shared `audio/ui/` path.

## v3.41
- **Added the missing Lock sound** — confirmed via device inspection that `/product/media/audio/ui/Lock.ogg` exists separately from `Unlock.ogg`, which we already supported. Added as a 34th sound with Custom/Stock support, placed right after Unlock in Feedback Sounds. No "Pack" option yet since we don't have a bundled alternate Lock sound file — only Custom/Stock are shown to avoid a picker option that would silently do nothing.

## v3.40
- **Moved Screenshot sound from "Camera Sounds" to "Feedback Sounds"** — it was miscategorized. Confirmed by pulling and inspecting `TranssionCamera.apk` directly: it has no screenshot-related audio asset at all, meaning Screenshot never went through the Camera app's self-contained sound system in the first place — it genuinely uses the shared `/product/media/audio/ui/` path our module already writes to correctly. The old grouping just implied it was camera-app-blocked when it isn't.
- **Root cause confirmed for the genuinely-broken camera sounds** (Burst Shot/camera_click, Video Start/Stop, Timer sounds, Shutter): `TranssionCamera.apk` bundles these as raw assets inside its own APK (`assets/camera_click.ogg`, `assets/video_record.ogg`, `assets/video_stop.ogg`, `res/raw/camera_continuous_shutter.ogg`, `res/raw/countdown_*.ogg`, etc.) — the app never reads the shared system sound path at all, so no amount of fixing `post-fs-data.sh`'s copy/permission logic could ever have made these work. Fixing this class of sound requires patching the Camera app's own bundled assets directly, which is a larger, separate undertaking — not yet implemented.

## v3.39
- **Actually fixed "turn off charging animation" reverting to stock**, not just removing the video. v3.36 disabled the `.mp4` file when the toggle was off, but left `lockscreen_charge_config.xml` active — that XML independently controls the custom charging screen's layout (battery percent text size, "CHARGE" label, gravity/scaling), so the system kept showing our custom layout with no video instead of genuinely falling back to stock. Both files are now disabled together when the toggle is off.

## v3.38
- **Replaced `FodSetOverlay.apk` with a custom-edited version** (modified `fp_animi_bg.webp` background asset, rest of the overlay unchanged). Verified file structure matches the original exactly before swapping — same resource layout, only the one intended asset differs — so the existing enable/disable gating in `post-fs-data.sh` (which operates on file path, not content) continues to work unchanged.

## v3.37
- **Fixed dynamic blur (dock/recents/app-drawer) never actually applying.** `ro.surface_flinger.supports_background_blur` was being toggled live via `resetprop` in both the WebUI and `service.sh` — but SurfaceFlinger reads this prop very early in boot, before either of those ever runs, so the live toggle had no reliable effect no matter what was restarted or rebooted. Compared this against a confirmed-working reference module (Transsos14Ultra), which ships this prop as a static always-on entry in `system.prop` instead — moved it there, along with `ro.os.recent.blur` (previously missing from our module entirely). The launcher-scoped blur props (`ro.transsion_launcher_gaussian_blur_support`, `tr_launcher.gaussianblur.support`, `ro.tran.effectengine.dynamicblur.support`) are read late enough to stay legitimately live-toggleable via the Dynamic Blur switch, unchanged.

## v3.36
- **Fixed charging animation staying on after being disabled + rebooted.** Turning the toggle off only ever flipped `ro.tran.charge_animation_support`/`lockscreen_charge_anim` — it never touched the actual `.mp4`, which stays mounted via the module's `/system` overlay regardless of that flag. `post-fs-data.sh` now disables the file itself before the mount happens (same pattern already used for boot sound), so "off" actually restores the stock animation.
- **Likely fix for individual UI sounds (Pack/Custom) not playing.** Files copied fresh at boot via `post-fs-data.sh` weren't getting the file permissions or SELinux context that `install.sh` only applies once, at install time — meaning freshly-copied sound files may have been unreadable by the audio system even though they existed correctly on disk. Added explicit `chmod 644` + `chcon --reference` after every sound copy, and logged the resulting permissions so this can be confirmed from the next `post_fs_data.log` pull rather than guessed at again.
- **XOS 16 is now the default status bar icon style**, replacing iOS, across every place the default was set (JS config default, HTML picker markup, subtitle text, install template, shipped config.json).
- **Boot Animation and Shutdown Animation moved from the Sounds tab to the Media tab**, alongside Charging Animation — all boot/shutdown/charging media now lives in one place.
- **Apply & Save now scopes its work by tab** instead of always running the full ~25-call runtime sequence everywhere. Media's Apply is config-write + app-restart only (nothing there needs a runtime prop pass). Home and Features still run the full sequence, since Home's quick toggles can change the same AI/game master switches Features controls.

## v3.35
- **Apply & Save now shows continuous live progress, not just a brief spinner.** The button's spin/"Applying…" state was already correct, but it only confirms work is starting — the toast that reports actual progress didn't update again until everything finished several seconds later, which read as the app hanging. The toast now updates through each real phase as it happens: Saving config → Animations → Display → Gaming → Charging & nav bar → AI features → AOD → Launcher blur → Restarting SystemUI → Restarting Launcher → Restarting charge animation.

## v3.34
- **Fixed inconsistent "some sounds work, some don't" behavior** — `setSoundStyle()` and `setStatusbarStyle()` (fired by every Pack/Custom/Stock and status-bar-style picker tap) only updated the in-memory config object and never wrote `config.json` to disk. Only tapping "Apply & Save" afterward actually persisted a change; a picker tap followed by any other action (another picker tap, a reboot, closing the app) before hitting Apply & Save silently lost that selection. Both setters now write to disk immediately after every tap, matching the same pattern uploads already used.

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
