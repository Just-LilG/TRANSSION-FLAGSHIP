#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_p "=== TransFlagship 16 V1.08 ==="
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
log_p "audio=$(service check audio 2>/dev/null) anim=$(getprop init.svc.bootanim 2>/dev/null) pid=$(pidof bootanimation 2>/dev/null) completed=$(getprop sys.boot_completed 2>/dev/null)"
log_p "zip audio members:"
( unzip -l /tr_product/media/bootanimation.zip 2>/dev/null || true ) | grep -iE 'audio|folder1|part1|desc' >> "$LOG"
log_p "restarted=$([ -f "$MODDIR/.bootanim_restarted" ] && cat "$MODDIR/.bootanim_restarted" || echo no)"

# Second chance: AOSP audioplay.cpp skips zip audio.wav forever if audioserver
# was not up when bootanim first started. Wait briefly while animation may
# still be up (late_start can race either side of bootanim).
if [ "$BS" != "off" ]; then
    n=0
    while [ "$n" -lt 15 ]; do
        if [ -f "$MODDIR/.bootanim_restarted" ]; then
            log_p "service skip restart (already: $(cat "$MODDIR/.bootanim_restarted" 2>/dev/null))"
            break
        fi
        chk=$(service check audio 2>/dev/null)
        anim=$(getprop init.svc.bootanim 2>/dev/null)
        case "$chk" in
            *found*) audio_ok=1 ;;
            *) audio_ok=0 ;;
        esac
        running=0
        [ "$anim" = "running" ] && running=1
        pidof bootanimation >/dev/null 2>&1 && running=1
        log_p "service wait audio='$chk' anim=$anim running=$running n=$n"
        if [ "$audio_ok" = 1 ] && [ "$running" = 1 ]; then
            if mkdir "$MODDIR/.bootanim_restart.lock" 2>/dev/null; then
                echo "service audio+bootanim" > "$MODDIR/.bootanim_restarted"
                log_p "service second-chance ctl.restart bootanim"
                setprop ctl.restart bootanim
                sleep 1
                log_p "after restart anim=$(getprop init.svc.bootanim 2>/dev/null) pid=$(pidof bootanimation 2>/dev/null)"
            else
                log_p "service skip restart (already claimed: $(cat "$MODDIR/.bootanim_restarted" 2>/dev/null))"
            fi
            break
        fi
        if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && [ "$running" = 0 ]; then
            log_p "service skip restart (boot already completed, anim gone)"
            break
        fi
        n=$((n + 1))
        sleep 1
    done
else
    log_p "service skip restart (boot sound off)"
fi
log_p "=== service complete (boot anim applied in post-fs-data) ==="
