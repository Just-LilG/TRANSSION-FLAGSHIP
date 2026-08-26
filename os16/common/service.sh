#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_p "=== TransFlagship 16 V1.11 ==="
log_p "Device : $(getprop ro.product.model 2>/dev/null)"
log_p "Brand  : $(getprop ro.product.brand 2>/dev/null)"
log_p "Android: $(getprop ro.build.version.release 2>/dev/null)"
log_p "ro.tran.os.type : $(getprop ro.tran.os.type 2>/dev/null)"
log_p "ro.transsion.os.version: $(getprop ro.transsion.os.version 2>/dev/null)"
log_p "ro.tran.sw.market: $(getprop ro.tran.sw.market 2>/dev/null)"
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
    rm -f /data/local/bootaudio.mp3
else
    resetprop persist.sys.bootanim.play_sound 1 2>/dev/null
    resetprop persist.sys.media.bootanim.play_sound 1 2>/dev/null
fi
log_p "boot_sound=$BS play_sound=$(getprop persist.sys.bootanim.play_sound 2>/dev/null)"
log_p "Transsion initAudioPath candidates:"
ls -l /product/media/audio/bootsound/Waltz.ogg \
      /tr_product/media/audio/bootsound/bootaudio.ogg \
      /data/local/bootaudio.mp3 >> "$LOG" 2>/dev/null
log_p "audio=$(service check audio 2>/dev/null) anim=$(getprop init.svc.bootanim 2>/dev/null) completed=$(getprop sys.boot_completed 2>/dev/null)"
CA=$(grep -o '"chargeanim_style"[[:space:]]*:[[:space:]]*[^,}]*' "$MODDIR/config.json" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
[ -z "$CA" ] && CA=hios16
if [ "$CA" != "off" ]; then
    resetprop ro.tran.charge_animation_support 1 2>/dev/null
    resetprop ro.tran.lockscreen_charge_anim 1 2>/dev/null
    am force-stop com.transsion.aichargeprovider 2>/dev/null
    log_p "chargeanim_style=$CA props=1"
else
    log_p "chargeanim_style=off — leave stock charge props"
fi
log_p "=== service complete (boot/reboot/charge anim applied in post-fs-data) ==="
