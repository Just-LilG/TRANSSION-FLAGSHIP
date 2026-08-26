# Transsion Flagship 16

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
