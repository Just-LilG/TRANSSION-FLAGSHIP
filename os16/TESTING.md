# Flagship 16 — Final test checklist (X6886 / OS 16)

Flash **V2.0.1** → reboot → WebUI **Apply & Save** → reboot again before testing.

After each section, note **PASS / FAIL / STOCK** (already had it). If FAIL, run **Dump flags** on Home and **Copy log**.

---

## 1. Media

| # | Test | How | Expected |
|---|------|-----|----------|
| 1.1 | Boot animation | Reboot | Custom pack plays (HiOS 16 default) |
| 1.2 | Reboot/shutdown anim | Restart / shutdown | Custom shutdown zip |
| 1.3 | Boot sound | Reboot | Pixel boot sound |
| 1.4 | Wired charge sound | Plug USB | Selected charging style |
| 1.5 | Wireless charge | Place on pad | Wireless charging sound |
| 1.6 | Unlock sound | Unlock phone | Pixel unlock |
| 1.7 | Custom sound upload | Sounds tab → upload → Apply | Plays after reboot |

---

## 2. AI Suite

| # | Test | How | Expected |
|---|------|-----|----------|
| 2.1 | AI Subtitles | Video with captions | Feature available |
| 2.2 | AI Call Summary | Phone → Ella briefing | Works |
| 2.3 | AI Notes draw | Notes app | AI draw option |
| 2.4 | AI Writing | Keyboard / writing | Suggestions |
| 2.5 | AI Sound Recorder | Recorder | Summary/transcription |
| 2.6 | AI Gallery | Gallery menus | Menus show; Art/Studio may not work on G99 |
| 2.7 | AI Video (VEE) | Video player | Enhancement flag on |
| 2.8 | Video Super Resolution | Video app | Toggle on in dump |
| 2.9 | AI Treasure Box | Settings / AI | May be device-dependent |

---

## 3. Gaming

| # | Test | How | Expected |
|---|------|-----|----------|
| 3.1 | XArena GT triggers | Game Space → triggers | GT option visible |
| 3.2 | eSports touch | Game Space | Touch level applies |
| 3.3 | Bypass charging | Game + charger | Bypass option in game |

---

## 4. Animations & blur

| # | Test | How | Expected |
|---|------|-----|----------|
| 4.1 | Parallel on | Open/close app | Smooth platform-3 motion |
| 4.2 | Blur level **2** (default) | Dock + pull shade | Dock blur; shade solid-ish |
| 4.3 | Blur level **3** | Pull shade | Full glass |
| 4.4 | Blur level **1** | Pull shade + app close | Solid shade; Parallel may glitch (known) |

Dump: `platform`, `perf_model`, `launcher vconfig platform`, `unionrender`.

---

## 5. AOD & display

| # | Test | How | Expected |
|---|------|-----|----------|
| 5.1 | AOD | Settings → Lock screen / AOD | Always-on works |
| 5.2 | DC dimming | Settings → Display | Row may or may not show |
| 5.3 | Color enhance | Settings → Display | Row may or may not show |
| 5.4 | HDR | Settings → Display | **Often missing on G99** — note FAIL if so |
| 5.5 | Reading mode | Settings | Off by default; toggle test |

---

## 6. Unlock extras

| # | Test | How | Expected |
|---|------|-----|----------|
| 6.1 | Resolution scale-up | Settings → Display | May already be on stock |
| 6.2 | GT app extras | Gallery / Scan / PC Connect / Zero Screen | Extra options if not stock |
| 6.3 | Circle to Search | Long-press home / nav handle | Circle search |
| 6.4 | Motion sickness | Settings → Special functions | Toggle row |

---

## 7. Extras

| # | Test | How | Expected |
|---|------|-----|----------|
| 7.1 | Super volume | Media volume max | Louder than stock |
| 7.2 | Social Turbo | Phone app during call | Stock already had on G99 |
| 7.3 | Outdoor boost | Settings | Stock already had |
| 7.4 | Air Transfer | Share menu | Stock already had |
| 7.5 | Cute Pet | Settings / launcher | **Often missing on G99** |
| 7.6 | Gallery Live | Gallery | GT dump off; keys only |
| 7.7 | Dynamic bar extras | Toggle **off** (default) | Stock pill unchanged |
| 7.8 | Force 120Hz | Enable → Apply → **reboot** | 120/144 in refresh picker |

---

## 8. Status bar

| # | Test | How | Expected |
|---|------|-----|----------|
| 8.1 | Custom overlay | Upload APK → Apply → reboot | Icons change |

---

## Reporting bugs

1. Home → **Dump flags** → copy output  
2. Home → **Copy log** (boot log)  
3. Note: module version, blur level, what you toggled, reboot vs Apply-only  

Paste all three when reporting a failure.
