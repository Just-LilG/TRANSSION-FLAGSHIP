# Transsion Flagship 16

## v1.57
- **AOD + Dynamic bar (first try).** OS 16 keys from the GT dump: `ro.tr_aod.feature.support`, `ro.tr_aod.doze.brightness.feature.support`, and `ro.tr_aod.half.screen.feature.support` (stock 0 on GT — that is the extra). Dynamic bar is `ro.tr_dynamicbar.support` as its own Features toggle (no longer tied to Parallel). Keys live in `/tr_product/etc/build.prop`, so this build also `resetprop`s them. Apply + reboot, then check Lock screen / AOD and the pill. Dump flags — EMPTY means this G99 still does not expose that key.

## v1.56
- **Removed failed features.** Social Turbo did not add anything this X6886 did not already have in stock Phone (call record / translate / beauty). Display extras (DC / color / HDR / reading) stuck flags on OS 16 but never unhid Settings rows after three tries — OS 16 Display is overlay/Settings-compiled, not those props. Force 120Hz stays. Apply + reboot so leftover Display settings writes are dropped.

## v1.55
- **Display extras (third try).** Same X6886 had DC / color / HDR / reading on Trans OS 15. V1.53–1.54 flags all stuck on 16 (`ro.tran.display_*`, `sdr2hdr`) but Settings still hid the rows. Dump showed `has_HDR_display=false` — OS 16 Settings likely ANDs that SurfaceFlinger bit. This build sets it to **true** when HDR is on, and writes Display settings the same way Flagship 15 did on this phone (`settings put` **and** `content update`). Apply + reboot, then Settings → Display. If HDR/DC still missing, dump and check `has_HDR_display` plus the new `dumpsys display` HDR lines.

## v1.54
- **Display extras (second try).** V1.53 wrote OS 16 `sdr2hdr` / `xdr` (those did stick) and Flagship 15 Settings keys, but Display in Settings did not change. This build also writes the Flagship 15 **gating** props that unhid those rows on XOS 15: `ro.tran.display_hdr_support` and `ro.tran.display_dc_dimming_support`, plus `tr_*` Settings aliases, then force-stops Settings. Apply + reboot, then open Settings → Display again. Dump flags — if those two `ro.tran.display_*` rows are EMPTY, this phone does not have that gate.

## v1.53
- **Display extras (first try).** Same Features card as Flagship 15: DC dimming, color enhancement, HDR, reading mode. HDR uses OS 16 keys from the GT dump (`ro.tr_display.sdr2hdr.support`, `ro.tr_light.xdr.support` / `xdr.v2` — stock is 0). Color uses `ro.tr_display.colormode` / `color.temperature`. DC and reading have no `ro.tr_*` in that dump, so they write the same Settings keys as Flagship 15 (`tran_dc_dimming_enable`, `tran_reading_mode_enable`). Reading stays off by default. Apply + reboot, then check Display / eye-comfort / HDR rows. Dump flags — EMPTY means this G99 still does not expose that key.

## v1.52
- **Social Turbo (first try).** Same Features card as Flagship 15, but OS 16 keys from the GT dump: `ro.tr_social.turbo_mode.support`, call record / translator / summary, sound change, makeup, and `beauty_disable` (0 = beauty on). Stock already has these in `/tr_product/etc/build.prop`, so Magisk `system.prop` is not enough — this build also `resetprop`s them at post-fs, late_start, and Apply. Defaults on. Apply + reboot, then check Phone / video-call tools. Dump flags — EMPTY means this G99 still does not expose that key.

## v1.51
- **Listed app refresh is 120, not 90.** Magellan `auto="90"` is what Customize App Refresh shows until you pick another rate. This build sets `auto="120"` on those apps (games stay `auto="144"`) and still keeps 144 in the picker. Force 120Hz on → Apply → reboot.

## v1.50
- **Control center / keyboard stay high refresh.** The TranOS XML that unlocked 144 had `input_method_switch` and `navigation_switch` off, so Magellan dropped those overlays to 60Hz. This build turns those switches on and gives SystemUI, launchers, and Gboard `max="144"`. Force 120Hz on → Apply → reboot, then check the on-screen Hz counter on home, QS, and keyboard.
- **Developer options game FPS is 120Hz.** Same Flagship 15 keys: `ro.surface_flinger.game_default_frame_rate_override=120` and `debug.graphics.game_default_frame_rate.disabled=true`. The row should read “Disable limiting the maximum frame rate for games at **120 Hz**” like other Trans OS. Applies even if Force 120Hz is off; reboot.

## v1.49
- **Last try for 144Hz: bind Magellan like bootanim.** Mountify v2 never overlays `/tr_product` (only product/vendor/odm/…). The TranOS zip’s `system/tr_product/` tree lands on `/system/tr_product`, which Magellan does not read — Customize stays stock (Messages/Phone/Settings in 144, Agent 1 picker 60/90/120). This build bind-mounts the exact TranOS XML onto `/tr_product/etc/vconfig/magellan/refresh_rate_config.xml` the same way bootanim reaches that partition, and also puts the file under `system/product/etc/vconfig/magellan/` so Mountify overlays `/product`. Force 120Hz on → Apply → reboot. If Agent 1 still has no 144 after this, Magellan is not using that XML on this phone and we move on.

## v1.48
- **Force 120Hz stays on after Apply.** V1.47 ran the TranOS installer’s `package_cache` wipe from WebUI Apply, which soft-rebooted the phone before `config.json` was flushed — the toggle came back off. Apply now writes the toggle (and a `.force_120hz` flag) then `sync`s, copies the Magellan XML for the next reboot, and does **not** wipe package cache or force-stop Settings. Apply should not reboot by itself. Then reboot once so Mountify overlays 144.

## v1.47
- **Force 120Hz uses the exact TranOS 16 custom refresh.xml.** That zip is only `system/tr_product/etc/vconfig/magellan/refresh_rate_config.xml` (Mountify overlay). V1.43–1.46 rewrote every item to `auto="120"` and `touch="0"`, then umount/bound `/tr_product` and fought Mountify. This build ships that XML unchanged (`auto="90"` + `max="144"` on the 144 list, including Chrome / Play / WhatsApp / Termux), appends any extra installed packages the same way, and does not bind Magellan. Disable the TranOS refresh zip. Force 120Hz on → Apply → reboot. The Customize App Refresh list can still show 90 until you pick 120/144.

## v1.46
- **Same layout as TranOS 16 custom refresh.zip.** That module works with Mountify because the Magellan XML lives in the module’s `system/tr_product/etc/vconfig/magellan/` tree — Mountify only copies `system/*`, then overlays `/tr_product`. V1.43–1.45 wrote the XML next to the module scripts (`magellan/`) and Magisk-bound `/tr_product` after Mountify had already copied; Magellan never saw it. This build writes the patched XML to `system/tr_product/...` on Apply and at install if Force 120Hz is already on, then you reboot so Mountify overlays it. Keep the custom refresh module **disabled**. Force 120Hz on → Apply → reboot.

## v1.45
- **Magellan XML is patched at post-fs, before system_server.** V1.44 bound a tiny seed list (Settings/Phone/Messages only) then filled every package at late_start. Magellan loads `tr_product/etc/vconfig/magellan/refresh_rate_config.xml` once when the policy starts — Agent 1 stayed in Other Apps with no 144. This build reads `/data/system/packages.list` at post-fs (no `pm`), **patches the stock XML** (`max="144" auto="120"` on every package, keep OEM version/attrs), then binds that file like bootanim. Mountify does not overlay `/tr_product` (only system/product/vendor/…). Apply + reboot once.

## v1.44
- **Force 120Hz goes through Mountify, like TranOS 16 custom refresh.zip.** That Telegram module is a 15.6KB Magellan XML: more apps on the 60/90/120/144 list, 120Hz multi-window/launcher, **flash with Mountify**. V1.43 Magisk-bound `/tr_product/etc/vconfig/magellan/refresh_rate_config.xml`, but Mountify remounts `/tr_product` and the bind loses. This build copies the generated XML into `/mnt/vendor/mountify/tr_product/etc/vconfig/magellan/` (per-file, not bind-dir), sets `multi_window_refresh_rate` to 120, and still fills every installed package with `auto="120" max="144"`. Disable the separate TranOS 16 custom refresh module so the two XMLs do not fight. Apply + reboot.

## v1.43
- **Force 120Hz targets XOS 16 Magellan, not the old APM JSON.** V1.42 overlaid `/product/apm/config` like XOS 15. This phone’s Customize App Refresh does not use that file: “Apps Supporting 144 Hz” is Magellan `max="144"` in `/tr_product/etc/vconfig/magellan/refresh_rate_config.xml` (Settings / Phone / Messages). Other apps have no `max="144"`, so the picker stops at 120 and the list stays 90. This build per-file binds that XML (not bind-dir `/tr_product`), writes **every installed package** as `auto="120" high="120" max="144"`, and copies it into `/data/magellan` if Magellan cached a copy. Off by default. Apply + reboot, then open Customize App Refresh — Agent 2 should be in the 144 section with 120 selected and 144 in the picker.

## v1.42
- **Force 120Hz uses the XOS 15 overlay path.** On 15 there was no 144 WebUI toggle — Force 120Hz wrote Settings and overlaid `/product/apm/config/*.json`. TranRefreshRatePolicy loads that path (`Environment.getProductDirectory()/apm/config/`), which is what put **144Hz as a choice on every app** in Customize App Refresh. V1.39–1.41 never shipped Magisk `system/product/apm/config/`, so the policy never saw the bypass and the list stayed 90 with no 144. This build overlays those files like Flagship 15, fills the whitelist with every installed package, and drops the Off/120/144 picker. Off by default. Apply + reboot, then **tap an app** in Customize App Refresh — 144 should be there. The list can still *show* 90 as the current value.

## v1.41
- **Force 120Hz still showed 90Hz on Customize App Refresh.** That list is Settings prefs / per-app keys, not the APM whitelist. V1.40 never wrote those, so “Other Apps” stayed at 90. This build writes a default for **every installed package**, clears the Policy120 90Hz-in-120-mode lists, and `resetprop`s `ro.tran_90hz_refresh_rate.not_support`.
- **Unlock 144Hz.** Same Display picker: Off / 120 / 144. 144 is this panel’s peak (60/90/120/144). Off by default. Apply + reboot. Open Customize App Refresh — Other Apps should show 120 or 144, not 90. Dump flags if the list is still 90.

## v1.40
- **Force 120Hz = default 120 for every app.** V1.39 copied Flagship 15’s **partial** APM whitelist, so Chrome / Play / Gallery and anything not listed could stay capped. That Flagship 15 list was never confirmed on Trans OS 15 either. This build, after `pm` is up (late_start and WebUI Apply), writes **every installed package** (system + user) into `auto_refresh_rate_whitelist`, `slide_in_higher_setting_mode_120hz`, and `high_refresh_rate_gameList_in_120hz_mode`, and clears 60/90/120 limit lists and the 45Hz video lists. Still a per-file bind only (not bind-dir `/tr_product`). Settings go to system **and** global, plus `persist.sys.peak_refresh_rate` / `min_refresh_rate`. Off by default; off does not force 60Hz. Apply + reboot. Dump flags — if `min_refresh_rate` reads back 60, the panel still clamped it. Check Settings, Chrome, Play Store, Gallery, SystemUI.

## v1.39
- **Force 120Hz (first try).** Same Transsion settings as Flagship 15 on this X6886: `tran_refresh_mode` / recovery keys, `peak_refresh_rate` / `min_refresh_rate`. Off by default (battery). Off does not force 60Hz. If a live APM `refresh_rate_config.json` exists, a per-file bind applies the 120Hz bypass (not a bind-dir of `/tr_product`). Features tab, Apply, reboot. Some apps may still sit below 120. Dump flags for the refresh keys.

## v1.38
- **Parallel animations stay on without flagship glass.** V1.37 dropped `platform_level` to 2 at blur level 1, so Parallel became basic motion. Device tests: glass followed Parallel/platform 3, but unionrender was also tied to Parallel. This build keeps **platform_level=3 whenever Parallel is on** (app open/close, recents). Blur off or **level 1** only turns off glass: unionrender, liquid glass, SurfaceFlinger blur. **Level 2/3** turns glass back on. Apply + reboot. Check Parallel at blur 1, then glass at blur 3.

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
