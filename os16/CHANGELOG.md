# Transsion Flagship 16

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
