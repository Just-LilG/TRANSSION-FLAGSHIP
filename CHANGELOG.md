# Changelog

## v4.23
- **Removed the duplicate "Off" option on the Signal & WiFi icon picker.** None and Off were both wired to the same `off` value, so choosing "no overlay" highlighted two buttons at once. The picker is now None / iOS / XOS 16 / Custom (Custom still appears only after you upload an overlay).

## v4.22
- **Fixed XOS 16 (and HiOS/iTel) props never actually applying.** Magisk's installer copies `common/system.prop` over the module's `system.prop` *after* `on_install` returns, which silently discarded every OS-specific append — including all of the XOS 16 animation/blur/dynamic-bar props this beta is built around. Appends now go to the file Magisk actually copies (`$TMPDIR/system.prop`).
- **Fixed XOS 16 fresh-install defaults.** Charging Animation, Fingerprint Animation, and the Signal/WiFi overlay now default to **off** on XOS 16 at flash time, matching the WebUI and README. Previously only "Reset to Defaults" in the WebUI used those defaults; a fresh flash still turned all three on for the first boot. Existing configs are still never overwritten. If you already flashed beta1 on XOS 16, turn those three off manually or tap Reset to Defaults.
- **Fixed the in-app update checker** pointing at a non-existent `v4.21/TransFlagship_V4_21.zip` and reporting `versionCode` 67 against the installed 68.
- **Fixed XOS 16 detection in the WebUI** only matching a literal `"16"`, so builds that report `16.0` / `16.1` / `XOS16` never showed the beta badge and used the wrong defaults.
- **Fixed `set_permissions` chmod'ing `$MODPATH/common/*.sh`**, which Magisk never copies there — the scripts it actually runs (`post-fs-data.sh` / `service.sh` at module root) now get executable permissions.

## v4.21
- **Fixed hint icons not responding to taps at all.** The previous `onclick="event.stopPropagation();..."` relied on the implicit global `event` object, which isn't reliably available in KernelSU's WebView. Now passes `event` explicitly as a function parameter (`showHint(event, msg)`), which works consistently. Also gave the icon a real 20×20px tap target instead of a bare character, which was too small to reliably hit on a phone screen.
- **Added the missing hint icons** to Custom Overlay, Status Bar (5G badge note), and Experimental Performance Tuning — the three sections flagged as still having long inline paragraphs instead of the condensed icon pattern. The live combo-warning banner (shown only when Force 120Hz + Performance Tuning are both on) stays fully visible rather than hidden behind a tap, since it's an active alert, not background info.
- **Reworked the floating tab bar to genuinely float over content** instead of sitting in its own dedicated background strip below the scrollable area. It's now `position:absolute` over `.pages`, so scrolled content is visible (blurred) behind and around it as intended, matching the reference design. Sized up roughly 10% (56px→62px height, 300px→330px max width, larger icons/padding) and pushed slightly higher off the bottom edge.

## v4.20 — IMPORTANT FIX
- **Actually fixed dual-metamodule installation this time, confirmed against real device data.** V4.18's fix looked for the literal string `metamodule=true`, but the actual official KernelSU "OverlayFS MetaModule" (id `meta-overlayfs`, by KernelSU Developers) uses `metamodule=1` instead — a different but equally valid convention we hadn't accounted for. Our own known-ID fallback list also had a typo (`meta-overlayfsx` instead of the real `meta-overlayfs`), so neither detection path caught it. Now matches both `metamodule=true` and `metamodule=1`, and the fallback list has the correct real ID. Tested against the exact `module.prop` content pulled from a real install, plus negative tests (`metamodule=false`, an unrelated `versionCode=1`) to confirm no false positives.
- If you're still seeing both metamodules installed from testing v4.18/v4.19, reflashing v4.20 alone won't remove the one that's already there — same as before, you'll need to manually delete one from `/data/adb/modules/`.

## v4.19
- **Fixed the Undo upload banner overflowing off-screen.** `.action-btn`'s base `width:100%` rule was fighting the button's inline `flex-shrink:0`, causing the Undo button to balloon past the banner's edge. Also removed a duplicate `display:none`/`display:flex` declaration in the same style attribute that could have caused the wrong one to win depending on cascade order.
- **Fixed the Dynamic Blur/Force 120Hz info icons doing nothing on tap.** They used the HTML `title` attribute, which only shows on hover — a state that doesn't exist on touchscreens, so tapping never did anything. Both now use `onclick` with a toast, which actually works on mobile.
- **Made the floating tab bar narrower and raised it higher off the bottom edge**, per feedback that it was stretching too close to full width. Max width dropped from 420px to 300px, height from 62px to 56px, bottom margin roughly doubled.

## v4.18 — IMPORTANT FIX
- **Fixed Mountify auto-install ignoring other metamodules.** The check only ever looked for `/data/adb/modules/mountify` specifically — if a *different* metamodule (e.g. Meta-Overlayfsx or similar) was already installed, TransFlagship didn't recognize it and installed Mountify anyway, resulting in two active metamodules at once. Since metamodules all compete to control the same low-level mount behavior, this isn't just redundant — it's a real risk of boot/mount instability. Detection now checks for `metamodule=true` in every installed module's `module.prop` (the standard convention Mountify itself uses) as the primary signal, plus a fallback list of known metamodule package IDs in case a given metamodule doesn't set that field. If any other metamodule is found, Mountify is correctly skipped and the WebUI explains why.
- If you installed v4.15–v4.17 alongside another metamodule, check `/data/adb/modules/` for both and consider removing one — reflashing v4.18 alone won't undo an install that already happened.

## v4.17
- **Fixed the splash-screen conflict Skip/Continue bug** — both buttons previously just dismissed the screen with no real difference. Continue now actually deletes the conflicting modules found (with a real confirmation dialog first, since it's destructive); Skip dismisses without touching anything.
- **Trimmed heavy explainer text** — the two large Dynamic Blur explanation cards were condensed into a small "ⓘ" hint on the toggle row itself (hover/long-press for the same info), rather than removed outright, since they explained genuinely useful reboot-required behavior.
- **Major Home tab rework**: added a top-right info button (matching the reference "Sweet Dreams" pattern) that opens a slide-in Info & Diagnostics panel. Sound Customization, Module Conflict Check, Mountify status, Live Status, and Service Log all moved there — Home now only shows Device info and the primary Apply/Reboot/Reset actions.
- **Removed Quick Toggles entirely** — they were a second, redundant control surface for Gaming/AI Suite that didn't reflect the real state as directly as the actual Features tab toggles. Cleaned up all now-dead code (`quickSave`, `syncQuick`, and every reference to the removed `q-game`/`q-ai` elements) rather than leaving orphaned functions behind.
- **Polished the floating tab bar** — deeper blur, larger corner radius, more pronounced shadow/glow, closer to the reference design.

## v4.16
- **Conflicts now actually appear on the loading screen**, correcting a gap from v4.12–v4.13 where "conflict detection" only showed up after the splash dismissed, on the Home tab — never during loading itself, despite that being the original ask. The splash screen now runs a real scan as its last loading step; if anything is found, it swaps into a dedicated conflict-review state showing each conflicting module and blocks with **Continue** (proceeds into the app) and **Skip** (dismisses without reviewing further) — matching the intended behavior. If no conflicts are found, the splash dismisses normally with no extra step.
- Refactored the conflict scan itself into a shared `scanForConflicts()` helper, used by both the splash screen and the existing manual "Check for Conflicts" button on Home, so there's one source of truth instead of duplicated scan logic.
- Fixed a duplicate `loadMountifyStatus()` call left over from v4.15.

## v4.15
- **Bundled Mountify (a real, third-party metamodule by xx/KOWX712 — "Globally mounted modules via OverlayFS") and auto-install it if not already present.** During install, TransFlagship's own script stages Mountify as a real, separate module and sources its actual, unmodified `customize.sh` — not a rewritten version — so Mountify's genuine safety checks (OverlayFS support, root manager compatibility, SUSFS version conflicts) remain fully intact and can still cause it to skip installation. If Mountify's own checks abort it, TransFlagship's install continues normally — confirmed via isolated testing that a subshell abort/exit doesn't propagate to kill the parent install.
- Added a "Mountify (Metamodule)" status card on Home showing whether it's installed, and if not, why (Mountify's own decision vs. a missing bundle) — reflects the real outcome recorded during install, not a guess.
- **Note on scope**: as with the earlier module-conflict feature, a volume-button confirm/cancel prompt during install isn't technically possible — Magisk's installer can't read button input mid-flash. Mountify installs silently by default per explicit request; its own compatibility checks are the only thing that can stop it.
- TransFlagship's `uninstall.sh` never touches Mountify — it's left installed as an independent module if the person wants to keep it.

## v4.14
- **Recents-ghosting combo warning**: live banner on Features shows when Force 120Hz + Performance Tuning are both enabled together — the confirmed, still-unresolved combination that causes doubled/ghosted recents rendering. Updates live as either toggle changes.
- **Sound upload undo**: every upload now backs up the file it's replacing before overwriting. A dismissible "Undo" banner appears on the Sounds tab after any upload, restoring the previous file (or reverting to Stock if there wasn't one).
- **Added README.md** — was missing from the repo since early in this project's history.
- **In-app "What's New"**: `install.sh` now bundles `CHANGELOG.md` into the flashed module. The WebUI shows the latest version's changes in a modal once per version, tracked via a marker file so it won't repeat.
- **Prop-level conflict detection**: Module Conflict Check (both at install time and on-demand) now also greps other modules' `system.prop` for the 8 specific prop keys that caused real, confirmed bugs this session — not just file-path overlap.
- **"Check for Updates" on Home**: fetches `update.json` from GitHub directly in the WebUI, compares `versionCode` against what's installed, and reports whether an update is available.

## v4.13
- **Added install-time conflict detection.** `install.sh` now checks the same 13 collision-prone paths against every other installed, enabled module during flash — before any files are written — and prints which modules conflict directly in the Magisk/KernelSU installer output. Results are also saved so the WebUI shows them automatically on first launch after install, without needing to tap "Check for Conflicts" manually.
- **Note on scope**: automatic uninstall-during-install with a volume-button cancel window (as originally requested) isn't technically possible — Magisk's installer runs non-interactively with no way to read button input during flash. Built the safe alternative instead: detect and clearly report conflicts at install time, then let the person review and choose to Disable (reversible) or Remove (permanent, confirmed via dialog) each conflicting module from the WebUI afterward. Nothing is ever touched automatically.
- Added Disable/Remove action buttons per conflicting module in the Module Conflict Check card, each requiring explicit confirmation before acting.

## v4.12
- **Added "Module Conflict Check" on Home.** Scans every other installed, enabled Magisk/KernelSU module for files at the 13 real paths this module writes to — the same paths that caused genuine collisions and bugs across this project's history (audio/ui, FOD overlays, signal icon overlay, apm config, charging theme, boot animation, sound packs). Shows which module(s) share which specific paths, so a real conflict can be diagnosed by disabling the other module rather than guessing. Correctly excludes itself and skips disabled modules.

## v4.11 — UI Rework
- **Added a splash screen** on launch — branded "TransFlagship / Flagship Unlocked," with a pulsing glow, gradient logo, and a progress bar that reflects genuine loading steps (config, device info, logs) rather than a fake timer, with a small minimum display time so it doesn't flash instantly on fast loads.
- **Converted the bottom tab bar to a floating pill design** — rounded corners, margin on all sides, blur/shadow, centered with a max-width so it doesn't stretch edge-to-edge on wider screens. Stayed in normal document flow (not `position:fixed`) so existing scroll-padding and toast positioning didn't need reworking.
- **Added page-switch and tab-tap animations** — pages now fade/slide in when you switch tabs instead of snapping instantly, and tab buttons scale down slightly on press for tactile feedback.
- **Removed all HTML section-divider comments** (`<!-- HOME -->`, `<!-- /app -->`, etc.), matching the comment-free state already applied to every script and the JS in v4.0.

## v4.10
- **Investigated why `min_refresh_rate` can't be forced to 120 on this device**: confirmed live that `settings put system min_refresh_rate 120.0` is accepted with no error but reads back as `60.0` immediately, with no delay — not a daemon reasserting it later, but an instant rejection/clamp at the framework level. Searched every settings namespace and prop list for a Transsion-specific equivalent; found none. This looks like a genuine platform-level constraint on this device rather than something fixable via `settings put`/`content update`. Updated the Force 120Hz description to accurately describe it as raising the allowed ceiling and bypassing the per-app policy, rather than implying a guaranteed floor it can't currently deliver.
- No functional changes — description/documentation only.

## v4.9 — CRITICAL FIX
- **Fixed a bug in v4.8 that silently killed all of `post-fs-data.sh` whenever Force 120Hz was enabled** — not just the refresh rate policy bypass, but boot sound, charging animation, all 25 individual sound overrides, and status bar style too, since they all run later in the same script. Confirmed via `post_fs_data.log` showing only its very first line and nothing after. Root cause: `[ -f "$BACKUP" ] || { [ -f "$REAL" ] && cp "$REAL" "$BACKUP"; }` — this compound conditional can return a non-zero exit status under Android's `sh` depending on which branch runs, and something in the execution chain appears to treat that as fatal, aborting the rest of the script. Replaced with plain nested `if` blocks, matching the style used everywhere else in this file. If you were on v4.8 with Force 120Hz enabled, your other sound/animation customizations may not have been applying at all — reflash v4.9 to restore them.

## v4.8
- **Found and fixed the real reason Force 120Hz was still capping some apps at 90Hz.** The module already ships a sophisticated per-app refresh rate policy engine at `system/product/apm/config/{refresh_rate_config,project_refresh_rate_config}.json` (confirmed authored for TransFlagship, with a device-specific entry for this exact Infinix X6886). Confirmed via the actual file contents that Chrome, Play Store, and Gallery weren't on its `auto_refresh_rate_whitelist`, and several limiting/blacklist keys could cap refresh rate regardless of the `tran_refresh_mode`/`peak_refresh_rate` settings from v4.7. When Force 120Hz is enabled, `post-fs-data.sh` now swaps in a bypass version of both config files (limiting/blacklist keys cleared, positive-intent lists like the whitelist and video-detection scopes left untouched) before Magisk mounts the module tree, and restores the original when disabled. The original files are backed up on first use, not overwritten.

## v4.7
- **Actually fixed Force 120Hz.** Two real bugs found via device data: (1) it was only ever applied by the WebUI's Apply & Save — `service.sh` never re-applied it at boot, so a reboot alone reverted everything, explaining "still not working after reboot"; (2) confirmed via `settings list system` that this device has a separate Transsion-proprietary refresh rate namespace (`tran_refresh_mode`, `tran_need_recovery_refresh_mode/rate`, `last_tran_refresh_mode_in_refresh_setting`) that backs the OEM's own "Customize App Refresh Rate" screen — this is very likely what was overriding the generic AOSP `peak_refresh_rate`/`min_refresh_rate` keys we were setting alone. Now sets all 6 keys, in `service.sh` (boot-persistent) as well as the WebUI, with the Transsion-specific keys written first in case the OEM's own handler reacts to them and resets the generic keys afterward.

## v4.6
- **Added "Force 120Hz" toggle to Display** — sets both `peak_refresh_rate` and `min_refresh_rate` to 120.0 via Settings.System, verified against real device data (`dumpsys display` confirmed this panel supports 60/90/120/144Hz, and `peak_refresh_rate`/`min_refresh_rate` were the actual live settings capping refresh rate at 60). Off by default since it affects battery life. Deliberately does not set an explicit "off" value — since we don't know each device's genuine stock default, forcing 60Hz on disable could override a real adaptive/144Hz default. Disabling requires a reboot to return to stock adaptive behavior.

## v4.5
- **Fixed doubled/ghosted recents rendering** (two overlapping copies of app content, e.g. "Welcome to TermWelcome to Termux") confirmed via live isolation testing to be caused specifically by `ro.transsion_recent_animation_support=3`. This prop wasn't present at all on stock — recents had no transition animation before this module — and value `3` triggers what looks like two overlapping animation passes on this launcher build rather than a single clean transition. Removed from `system.prop` entirely rather than guessing at an alternate "safe" value, since we have no evidence for what value (if any) works correctly. The sibling prop `ro.transsion.recent_animation.model=3` was ruled out by the same test and stays in place.

## v4.4
- **Added SurfaceFlinger buffer/compositor tuning to fix recents showing overlapping/ghosted app previews.** `ro.surface_flinger.max_frame_buffer_acquired_buffers=4` gives the compositor more buffer depth so frames fully swap before the next one is requested — the most likely real fix for stale overlapping frames in recents. Also added `debug.sf.hw`, `debug.egl.hw`, and `debug.sf.latch_unsignaled` (forces hardware compositing paths and changes buffer fence handling) at the person's explicit request, despite these being more speculative/debug-namespaced and carrying real risk of visual artifacts on some GPU drivers — always-on since these are boot-time-read props with no live-toggle path. Deliberately excluded `debug.sf.show_background=true` from the source reference, which looks like a debugging artifact rather than an intentional feature.
- Found and removed a duplicate `ro.os_dynamicbar_ai_translation_support` entry in `system.prop`.

## v4.3
- **Added "Experimental: Performance Tuning" toggle on Features**, off by default. Sourced from a third-party module (Tran.OS.Opt) confirmed working on XOS 16, but not independently verified by us and untested on HiOS/iTelOS. Applies `ro.tr_animation.platform_level`, the four `ro.tr_perf.*` animation model props, `ro.tran_display_unionrender.support`, and `ro.tr_dynamicbar.support` when enabled. Deliberately does NOT touch these props at all when disabled, since we don't yet know their genuine safe/default values — turning it off requires a reboot to fully revert to stock. Clearly labeled as experimental in-app.
- Explicitly did **not** carry over the source module's vibrator-disabling behavior — that module permanently kills the vibration motor as an undisclosed side effect unrelated to its stated animation/blur purpose, which has nothing to do with performance tuning and wasn't something the person asked for.

## v4.2
- **Fixed Device name showing "—" on Home.** Confirmed via real device data that `ro.product.model` (and 4 other previously-tried props) are genuinely empty on this Infinix X6886/MT6789 build. Added and reordered fallbacks based on actual on-device output — `ro.product.odm.model`, `ro.product.product.model`, and `ro.product.tr_product.model` all correctly return "Infinix X6886" on this device and are now tried before falling back to less-friendly codenames like `ro.product.name`.

## v4.1
- **Added a "Sound Customization" summary card on Home** — shows how many of the 25 individual sounds are currently Custom/Pack vs Stock at a glance, with a direct link into the Sounds tab. Previously the only way to know what was set was scrolling through all 25 pickers individually.
- **Fixed "Reset to Defaults" warning being misleading.** It only mentioned "toggle choices," but the action actually wipes every setting including all 25 sound selections and uploaded custom files. The confirmation dialog now states the real scope.

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
