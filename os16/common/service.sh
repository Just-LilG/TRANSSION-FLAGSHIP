#!/system/bin/sh

MODDIR=${0%/*}
CFG="$MODDIR/config.json"
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

cfg_get() {
    [ -f "$CFG" ] || { echo "$2"; return; }
    val=$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" \
          | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
    [ -n "$val" ] && echo "$val" || echo "$2"
}
cfg_bool() { [ "$(cfg_get "$1" "$2")" = "true" ] && echo 1 || echo 0; }

log_p "=== TransFlagship 16 V1.17 ==="
log_p "Device : $(getprop ro.product.model 2>/dev/null)"
log_p "Brand  : $(getprop ro.product.brand 2>/dev/null)"
log_p "Android: $(getprop ro.build.version.release 2>/dev/null)"
log_p "ro.tran.os.type : $(getprop ro.tran.os.type 2>/dev/null)"
log_p "ro.transsion.os.version: $(getprop ro.transsion.os.version 2>/dev/null)"
log_p "tr_product: $([ -d /tr_product ] && echo yes || echo no)"
if [ -f "$MODDIR/install_diagnostic.txt" ]; then
    while IFS= read -r line; do log_p "$line"; done < "$MODDIR/install_diagnostic.txt"
fi
log_p "config: $([ -f "$CFG" ] && cat "$CFG" || echo missing)"

AM=$(cfg_bool ai_master false)
if [ "$AM" = "1" ]; then
    resetprop ro.sys.tran.ai_subtitles_support $(cfg_bool ai_subtitles true)
    resetprop ro.sys.tran.aiphone_summary_support $(cfg_bool ai_call_summary true)
    resetprop ro.os_soundrecorder_speech_support $(cfg_bool ai_sound_rec true)
    resetprop ro.os_ai_notification_summary_sr_sa_0003_001_support $(cfg_bool ai_notif_summary true)
    resetprop ro.os_note_ai_bg_support $(cfg_bool ai_notes true)
    resetprop ro.os_note_ai_draw_support $(cfg_bool ai_notes true)
else
    resetprop ro.sys.tran.ai_subtitles_support 0
    resetprop ro.sys.tran.aiphone_summary_support 0
    resetprop ro.os_soundrecorder_speech_support 0
    resetprop ro.os_ai_notification_summary_sr_sa_0003_001_support 0
    resetprop ro.os_note_ai_bg_support 0
    resetprop ro.os_note_ai_draw_support 0
fi
log_p "AI suite master=$AM"
log_p "  subtitles=$(getprop ro.sys.tran.ai_subtitles_support 2>/dev/null)"
log_p "  call_summary=$(getprop ro.sys.tran.aiphone_summary_support 2>/dev/null)"
log_p "  notif_summary=$(getprop ro.os_ai_notification_summary_sr_sa_0003_001_support 2>/dev/null)"
log_p "  sound_rec=$(getprop ro.os_soundrecorder_speech_support 2>/dev/null)"
log_p "  notes_bg=$(getprop ro.os_note_ai_bg_support 2>/dev/null)"
log_p "  notes_draw=$(getprop ro.os_note_ai_draw_support 2>/dev/null)"
log_p "=== service complete ==="
