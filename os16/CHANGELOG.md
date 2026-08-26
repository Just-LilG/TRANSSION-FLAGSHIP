# Transsion Flagship 16

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
