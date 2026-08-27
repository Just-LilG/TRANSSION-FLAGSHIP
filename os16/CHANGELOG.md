# Transsion Flagship 16

## v1.37
- **System glass is Parallel animations at platform 3, not the blur picker.** Device test: 1/2/3 only changed the dock while Parallel stayed on. Turning Parallel off is what made notifications/QS solid. Flagship glass now requires **Parallel on and blur level 2 or 3** (`platform_level=3`, unionrender, liquid glass). Parallel on + blur off or **level 1** uses platform **2** (motion without flagship glass). Parallel off keeps platform 0. Removed the level-1 lock-clock solid scrim (`accessibility_reduce_transparency` / blur radius while compositor off). Apply + reboot. Check shade with Parallel on and level 1 vs 3.

## v1.36
- **System blur is SurfaceFlinger, not the dock.** Off and level 1 only dimmed launcher gaussian — notifications/QS stayed flagship glass because SystemUI restart does not recreate the compositor. This build sets `persist.sys.sf.disable_blurs` / `supports_background_blur` then **restarts SurfaceFlinger**. **Level 1** = Smart-series solid shade. **Level 2/3** = flagship glass (dock gaussian 2 vs 3). **Off** = Smart shade and no dock blur. Apply flickers the screen; reboot. Pull down notifications to check.

## v1.35
- **Notification / QS blur is SystemUI, not the dock.** Off was supposed to look like Smart-series (solid panels, slight transparency). V1.31 turned flagship Gaussian on; V1.33–V1.34 only restarted the launcher, so the shade kept the glass. SystemUI caches `persist.sys.sf.disable_blurs` until that process dies. This build also writes `persist.sysui.disableBlur`, `wm disable-blur`, and `accessibility_reduce_transparency`, then **restarts System UI**. Levels 1/2/3 still map gaussian + radius (20/45/80); compositor blur itself is on with the toggle and off without it. Apply (shade will flicker), then reboot. Pull down notifications — should be solid when off.

## v1.34
- **Blur off/level: resetprop after overlay.** V1.33 still left glass on: Magisk `system.prop` does not override stock `ro.tr_display.liquidglass.support=1` from `/tr_product/etc/build.prop`, settings/wm only hit `com.transsion.launcher3` (this phone may use XOSLauncher), and gaussian keys are often EMPTY. This build `resetprop`s liquid glass, SurfaceFlinger blur, recents blur, gaussian level, `persist.sys.sf.disable_blurs`, and `ro.sf.blurs_are_expensive` in post-fs-data, at late_start, 8s later, and on Apply. Force-stops the default home app plus `launcher3` / `XOSLauncher` / `hilauncher`. Apply, then reboot. Dump flags — if liquidglass is still 1 after reboot, paste that log.

## v1.33
- **Blur off and blur level actually apply.** V1.32 left OS 16 liquid glass on with Parallel animations, so turning Dynamic blur off did nothing. The 1/2/3 picker only wrote Flagship 15 gaussian keys (often EMPTY here). This build: liquid glass follows Dynamic blur; Apply writes AOSP `disable_window_blurs` / `wm disable-blur`, `persist.sys.sf.disable_blurs`, and `transsion_launcher_blur_radius` (20 / 45 / 80 px for levels 1 / 2 / 3). Restarts the launcher. Apply, then check dock/recents. Reboot still needed for SurfaceFlinger.

## v1.32
- **Blur level picker.** Dynamic blur stays a toggle; Features now has 1 / 2 / 3 like eSports. Writes `ro.transsion_launcher_gaussian_blur_support` and `tr_launcher.gaussianblur.support` to that level (0 when blur is off). Default **2** (same as V1.31). SurfaceFlinger / recents / dynamic-blur engine stay on/off with the toggle. Apply + reboot.

## v1.31
- **Parallel / system animations + dynamic blur.** Same Magisk `system.prop` path as AI and Gaming. Writes OS 16 `ro.tr_animation.platform_level` and `ro.tr_perf.*` models at **3** (GT dump stock is 2; 3 is the Flagship 15 higher-tier), plus async / unlock / launch / keyguard, liquid glass, dynamic bar, dream wallpaper, and multi-window arc. Blur writes SurfaceFlinger background blur early (live `resetprop` does not apply), recents blur, and launcher gaussian / dynamic blur. Does **not** write `ro.transsion_recent_animation_support=3` — that doubled recents on Flagship 15. Features tab: two toggles, default on. Apply + reboot, then check app open/close, recents, dock blur. Dump flags — EMPTY means the key is not on this phone.

## v1.30
- **XArena GT Triggers use OS 16 keys.** V1.29 wrote Flagship 15 names (`ro.os_game_*`) — those are EMPTY here. This build writes `ro.tr_game.shoulder_key.support`, `ro.tr_game.ai_picture_triggers.support`, virtual ctrl / screen buttons / magic button, and `ro.tr_smartbutton.shoulderbutton20`. eSports and bypass also switch to `ro.tr_game.*`. Apply + reboot, then look in XArena for **add GT triggers**. This phone still has no physical trigger hardware.

## v1.29
- **AI Suite moved to Features.** Same place as Flagship 15: Home is device + dump, Media is animations, Features is AI + Gaming + status bar.
- **Gaming (first try).** eSports Touch (levels 1–3) and Bypass Charging, using Flagship 15 key names. Open Game Space after Apply + reboot. Dump flags — EMPTY means OS 16 uses different names (same lesson as AI).

## v1.28
- **AI Call Summary / Ella briefing on.** Turning the toggle on unhid Ella briefing on this phone. This build writes `aiphone` / `aiphone_summany` as `true` by default (upgrade from earlier builds turns the toggle on). Apply + reboot. GT generative Gallery is still not bundled.

## v1.27
- **AI Video Enhancement back on.** V1.24–V1.26 left `ro.tr_video.vee.support` at `0`. This build writes it to `1` again (toggle on by default; upgrade from those builds turns it back on). Apply + reboot, then check video playback. Gallery menus stay as in V1.26.

## v1.26
- **All AI Gallery menus for show.** V1.25 only unhid Eraser/Expand. This build writes every Gallery key to `1` again: Art, Studio lite, eraser, expand, HD, group/shadow enhance, bokeh, compose. Video VEE stays off. Tapping Art/Studio/HD can still crash AI Gallery Edit — this phone has the menus, not the GT editor/models. Apply + reboot, then check Gallery.

## v1.25
- **Gallery eraser/expand back on.** Tapping V1.23’s new tools crashed AI Gallery Edit — Art/Studio/HD need a GT editor this phone does not have. This build only turns on `eraser.v2` and `ext.image` (AICore erase/expand are already `1` on device). Art, Studio lite, HD, bokeh, compose, and VEE stay `0`. Try Eraser and Expand in Gallery after reboot.

## v1.24
- **AI Gallery / video off.** V1.23 unhid GT Gallery and VEE menus, but **AI Gallery Edit keeps stopping** — this phone has the flags, not the GT editor/models. Those keys go back to `0`. Settings AI Suite stays on. Leave the Gallery and video toggles off.

## v1.23
- **AI Gallery + video enhancement.** The Settings toggles were not the GT Gallery/video set. This build writes OS 16 Gallery keys (AI Studio lite, AI Art, eraser, expand, HD, group/shadow enhance, bokeh, compose) and `ro.tr_video.vee.support`. Stock often leaves those at `0` even on GT firmware — we force them on. Apply + reboot, then check Gallery (AI Studio / enhance) and video playback. Dump AI flags after reboot. These still need the Gallery/video engines on the phone; a missing model can show a menu that does nothing.

## v1.22
- **AI Suite restored.** The V1.21 hide test worked: those five OS 16 keys removed some Settings AI options. This build turns them back on (stock `=1`). Apply in WebUI rewrites Magisk `system.prop` from the toggles — reboot, no `resetprop` on boot. Master on by default; upgrade from V1.21 turns it back on. AI Writing replaces Notification Summary (`ro.os_ai_writing.support`). Call summary stays stock-off (`aiphone` / `aiphone_summany`). Dump + Copy log still on Home.

## v1.21
- **OS 16 AI keys off.** Device dump showed Flagship 15 names at 0 with stock AI still visible. This phone uses `ro.tr_*` keys. Magisk `system.prop` now sets off: speech subtitles, live caption, sound-recorder summary, notes draw, and AI writing. Dump AI flags + Copy log after reboot. If those Settings options hide, the keys are real.

## v1.20
- **Copy log on Home.** Dump AI flags (and the boot log) can be copied with one tap. Dump also tries to copy automatically.

## v1.19
- **Dump AI flags.** Setting those Flagship 15 keys to 0 did not hide stock AI — they may not exist on OS 16 at all. Home has **Dump AI flags**: EMPTY means the key is not on the phone (or Magisk did not apply it); `=0` with AI still visible means the ROM ignores that key. The dump also lists other live AI-like keys and whether the six names appear in stock build files. Paste that log.

## v1.18
- **AI flags in Magisk `system.prop`, not late boot.** V1.17 set them to off from `service.sh` after boot had already started; stock AI stayed. This build writes the six AI flags as **0** in the module property file Magisk loads early, and does not `resetprop` them from the boot script or from Apply. After reboot, stock AI should hide if the ROM reads these flags.

## v1.17
- **AI Suite defaults off** so we can tell if the props actually work. V1.16 defaulted on, but stock OS 16 already had those AI options, so nothing visible changed. This flash turns the master switch **off** (including an upgrade from V1.16). After reboot, stock AI should disappear if the flags are real. Turn AI Suite back on in WebUI if they vanish and you want them again.

## v1.16
- **AI Suite.** Same master + sub-toggles as Flagship 15 (subtitles, call summary, notification summary, sound recorder, notes). Applied with `resetprop` at boot and on Apply — no overlay files. Default on. After flash, look in Settings for those AI options. If nothing appears, this OS 16 build may not read the props.

## v1.15
- **Custom status-bar overlay only.** The bundled iOS / XOS 16 overlay APKs from V1.14 are removed (flash also deletes leftover copies). Home keeps an upload for your own signal/WiFi overlay APK, plus **None** for stock icons.

## v1.14
- **Signal & WiFi icon style.** None (stock, default) / iOS / XOS 16 / Custom overlay. XOS 16 also forces the network-type badge to 5G. Pick a style on Home, Apply, reboot, then check the status bar.

## v1.13
- **Dropped failed features to shrink the zip.** Charging animation (V1.11–V1.12) and boot sound (V1.02–V1.09) never applied on device. Their packs, WebUI, and apply code are removed. Flash cleans leftover overlay copies from those builds. **Kept:** boot animation and reboot animation (verified).

## v1.12
- **Charging animation overlay.** V1.11 bind-mounted a live charge folder that often does not exist on OS 16 (read-only overlay, mkdir fails). Files are now staged into the module overlay tree at install — the same way boot animation reaches `/tr_product` — then applied again at boot with per-file bind. Home has a charge dump if it is still missing.

## v1.11
- **Charging animation.** Same XOS / HiOS 16 / Custom / Off picker as boot and reboot. Applies the lockscreen charge theme under `/tr_product/theme/charge` (bind that folder only — not `/tr_product` or `/theme`). XML `resourcePath`, `fileName`, and `fileMd5` are rewritten on boot so the OS accepts the chosen mp4. Off leaves stock. Plug the charger in on the lockscreen after Apply + reboot.

## v1.10
- **Reboot animation.** Same XOS / HiOS 16 / Custom / Off picker as boot, applied to the shutdown splash that plays when you restart or power off. WebUI no longer shows internal file paths on Media or Sounds.

## v1.09
- **Boot sound via Transsion MediaPlayer paths (from the X6886 firmware dump).** `libbootanimation.so` `initAudioPath()` does **not** play zip `audio.wav`. It looks for, in order: `/product/media/audio/bootsound/Waltz.ogg`, `/tr_product/media/audio/bootsound/bootaudio.ogg`, `/data/local/bootaudio.mp3`. Stock ships none of those files, so boot is silent. V1.09 places Waltz on those three paths (bind-file / overlay / copy — not bind-dir of `audio/`). Custom **.ogg** or **.mp3**. Set Sounds to **Waltz**, flash, reboot.

## v1.08
- **Boot sound via zip `audio.wav` + audio-service restart.** Stock dump on X6886: no PowerOn.ogg, no sibling `bootsound.mp3`, no tinyplay. The 52KB `bootanimation` binary is AOSP `audioplay.cpp` — it plays `folder1/audio.wav` (XOS) / `part1/audio.wav` (HiOS) and only if AudioFlinger is already up. If not, it logs "Audio service is not ready yet" and never retries. V1.08 packs a canonical 48 kHz stereo PCM wav in those part folders, keeps `play_sound=1`, and restarts bootanim once `service check audio` returns found while the animation is still running. Custom should be **.wav**. Set Sounds to **Waltz**, flash, reboot. If silent, Home dump should show `wait audio=... anim=running` and `ctl.restart bootanim`.

## v1.07
- **Boot sound via Unisoc sibling file.** XOS 16 `desc.txt` is `folder1`/`folder2` (Unisoc), which plays `bootsound.mp3` **next to** `bootanimation.zip`, not AOSP `part/audio.wav`. Tinyplay is often missing. V1.07 copies Waltz to `/tr_product/media/bootsound.mp3` (and `.ogg`) through Mountify's overlay lowerdir — without bind-dir of `audio/`. Custom ogg works on this path. Set Sounds to **Waltz**, flash, reboot.

## v1.06
- **Installer no longer OOM-killed on KernelSU.** KernelSU unpacks the zip first, then the Magisk installer was deleting that tree and unzipping the two bootanim zips again (`Killed` in the install log). V1.06 keeps the extracted files and only refreshes scripts / webroot / boot-sound wavs.

## v1.05
- **Boot sound without overlaying `/tr_product/media/audio`.** V1.04 bind-dir nested alarms/notifications and hid stock UI sounds. XOS 16 has no `PowerOn.ogg` for overlay, and Transsion bootanim still did not play zip `audio.wav` (dump: wav in `folder1/` + `play_sound=1`, silence). V1.05 keeps the zip bind, injects a small 22 kHz `audio.wav`, and plays Waltz/custom with **tinyplay/aplay** during bootanim. Custom **.wav** is the reliable upload; .ogg is converted only if ffmpeg is on the device (Termux). Set Sounds to **Waltz**, flash, reboot.

## v1.04
- **Boot sound actually in the animation.** V1.02 put `audio.wav` at the zip root (`zip -j`). Android 16 bootanim only plays `part1/audio.wav` / `folder1/audio.wav` (the first finite part) and only if `persist.sys.bootanim.play_sound` is not 0. Waltz is now stored in those part folders; custom should be a **.wav**.

## v1.03
- Boot sound lives on the **Sounds** tab (same as Flagship 15). Media is boot animation only.

## v1.02
- **Boot sound.** Waltz / Custom / Off. Injects `audio.wav` into the staged bootanimation zip (AOSP plays WAV from the zip), merges stock `/tr_product/media/audio` then overlays Waltz, and bind-mounts that audio tree — not the whole `/tr_product/media` folder. Home has a **Dump audio paths** button if sound is silent.

## v1.01
- Boot animation style label: **XOS** (was Default). Same `bootanim_default.zip`; existing `default` configs still apply.

## v1.00
- New module for Transsion OS 16 (XOS / HiOS / iTel). Separate from Flagship 15.
- **Boot animation** is the first feature: XOS / HiOS 16 / Custom / Off, bind-mounted over `/tr_product/media/bootanimation.zip` (and any other live zip found). Reboot required.
- Installer disables Flagship 15 if it is still active so the two modules do not fight over media files.
