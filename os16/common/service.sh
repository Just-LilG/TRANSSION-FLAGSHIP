#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_p "=== TransFlagship 16 V1.18 ==="
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
log_p "AI props (from Magisk system.prop, not written here):"
log_p "  subtitles=$(getprop ro.sys.tran.ai_subtitles_support 2>/dev/null)"
log_p "  call_summary=$(getprop ro.sys.tran.aiphone_summary_support 2>/dev/null)"
log_p "  notif_summary=$(getprop ro.os_ai_notification_summary_sr_sa_0003_001_support 2>/dev/null)"
log_p "  sound_rec=$(getprop ro.os_soundrecorder_speech_support 2>/dev/null)"
log_p "  notes_bg=$(getprop ro.os_note_ai_bg_support 2>/dev/null)"
log_p "  notes_draw=$(getprop ro.os_note_ai_draw_support 2>/dev/null)"
log_p "=== service complete ==="
