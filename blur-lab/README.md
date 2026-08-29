# Transsion Blur Lab

Tiny Magisk / KernelSU module. **No WebUI.** Used to find which prop set unlocks full blur (shade + dock + folders) on XOS 16.

Disable **Transsion Flagship 16** while this is installed so the two modules do not fight.

## Use

1. Flash `TransBlurLab_V1.zip`
2. Reboot
3. Check shade, dock, folders, recents
4. To try another set: edit `/data/adb/modules/transsion-blur-lab/combo` to a number `1`–`6`, save, reboot (reboot a second time if compositor keys changed)

The installer prints which combo is active. Late log: `/data/adb/modules/transsion-blur-lab/lab.log`

## Combos

| # | Name | What it turns on |
|---|------|------------------|
| 1 | shade | Platform 3, liquid glass, SurfaceFlinger blur, recents, unionrender, dynamicblur. No dock/folder keys. |
| 2 | dock15 | Flagship 15 dock style: gaussian **2** + enable **1**. No platform / liquid glass. |
| 3 | dock16 | Gaussian **3**, folder **3**, blurrecent **1**, enable **1**. No platform / liquid glass. |
| 4 | full | Combo 1 + combo 3 (current Flagship 16 blur-on set). |
| 5 | full+ | Combo 4 plus lighting keys, settings, device_config, launcher3 vconfig bind. **Default.** |
| 6 | full-g2 | Same as 5 but gaussian / folder **2** (in case this launcher rejects 3). |

## After a test

Write down: combo number, what blurred, what stayed solid. That tells us which keys the dock actually reads.
