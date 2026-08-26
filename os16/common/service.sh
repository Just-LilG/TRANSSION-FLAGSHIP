#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_p "=== TransFlagship 16 V1.06 ==="
log_p "Device : $(getprop ro.product.model 2>/dev/null)"
log_p "Brand  : $(getprop ro.product.brand 2>/dev/null)"
log_p "Android: $(getprop ro.build.version.release 2>/dev/null)"
log_p "ro.tran.os.type : $(getprop ro.tran.os.type 2>/dev/null)"
log_p "ro.transsion.os.version: $(getprop ro.transsion.os.version 2>/dev/null)"
log_p "tr_product: $([ -d /tr_product ] && echo yes || echo no)"
if [ -f "$MODDIR/install_diagnostic.txt" ]; then
    while IFS= read -r line; do log_p "$line"; done < "$MODDIR/install_diagnostic.txt"
fi
log_p "config: $([ -f "$MODDIR/config.json" ] && cat "$MODDIR/config.json" || echo missing)"
BS=$(grep -o '"boot_sound"[[:space:]]*:[[:space:]]*[^,}]*' "$MODDIR/config.json" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
[ "$BS" = "true" ] && BS=waltz
[ "$BS" = "false" ] && BS=off
[ -z "$BS" ] && BS=waltz
if [ "$BS" = "off" ]; then
    resetprop persist.sys.bootanim.play_sound 0 2>/dev/null
    resetprop persist.sys.media.bootanim.play_sound 0 2>/dev/null
else
    resetprop persist.sys.bootanim.play_sound 1 2>/dev/null
    resetprop persist.sys.media.bootanim.play_sound 1 2>/dev/null
fi
log_p "boot_sound=$BS play_sound=$(getprop persist.sys.bootanim.play_sound 2>/dev/null)"
log_p "bootanim svc=$(getprop init.svc.bootanim 2>/dev/null) boot_completed=$(getprop sys.boot_completed 2>/dev/null)"
ls -l /system/bin/tinyplay /vendor/bin/tinyplay /system/bin/aplay /dev/snd >> "$LOG" 2>/dev/null

# Second chance only while bootanim is still up. Do not chime after lockscreen.
WAV=""
[ -f "$MODDIR/.boot_play.wav" ] && WAV=$(cat "$MODDIR/.boot_play.wav")
if [ "$BS" != "off" ] && [ -n "$WAV" ] && [ -f "$WAV" ]; then
    if [ "$(getprop init.svc.bootanim 2>/dev/null)" = "running" ] \
        || [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; then
        player=""
        for p in /system/bin/tinyplay /vendor/bin/tinyplay /system_ext/bin/tinyplay \
                 /system/bin/aplay /vendor/bin/aplay; do
            [ -x "$p" ] && { player="$p"; break; }
        done
        if [ -n "$player" ]; then
            log_p "service tinyplay: $player $WAV"
            "$player" "$WAV" >> "$LOG" 2>&1 || "$player" "$WAV" -D 0 -d 0 >> "$LOG" 2>&1
            log_p "service tinyplay done rc=$?"
        else
            log_p "service tinyplay: no player"
        fi
    else
        log_p "skip service tinyplay (boot already completed)"
    fi
else
    log_p "service tinyplay: no wav marker"
fi
log_p "=== service complete (boot anim applied in post-fs-data) ==="
