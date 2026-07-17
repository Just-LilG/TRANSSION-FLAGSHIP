#!/system/bin/sh

MODDIR="/data/adb/modules/transsion-flagship"
CFG="$MODDIR/config.json"
ACTIVE="$MODDIR/device_active.txt"
LOG="$MODDIR/transflagship_service.log"

rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

: > "$ACTIVE"
if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
    if ! cmd settings get global airplane_mode_on >/dev/null 2>&1; then
        echo "CMD_DISPATCHER_UNRELIABLE" >> "$ACTIVE"
        log_p "CMD_DISPATCHER_UNRELIABLE — content update fallback active"
    fi
fi

settings_put() {
    if ! grep -qx "CMD_DISPATCHER_UNRELIABLE" "$ACTIVE" 2>/dev/null; then
        settings put "$1" "$2" "$3" >/dev/null 2>&1
    fi
    content update --uri content://settings/"$1" \
        --bind value:s:"$3" \
        --where "name='$2'" >/dev/null 2>&1
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
WAIT=0
while [ "$WAIT" -lt 20 ]; do
    cmd settings get global airplane_mode_on >/dev/null 2>&1 && \
    pm path android >/dev/null 2>&1 && break
    sleep 1; WAIT=$((WAIT+1))
done
log_p "Boot ready (waited ${WAIT}s)"

resetprop sys.trancare.performance 1
resetprop sys.trancare.performance.latency 1
resetprop sys.camera_start_optimize 1
resetprop sys.intelligent_optimization_update 1
log_p "sys.* props forced"

cfg_get() {
    [ -f "$CFG" ] || { echo "$2"; return; }
    val=$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" \
          | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
    [ -n "$val" ] && echo "$val" || echo "$2"
}
cfg_bool() { [ "$(cfg_get "$1" "$2")" = "true" ] && echo 1 || echo 0; }
cfg_int()  { cfg_get "$1" "$2"; }

settings_put global window_animation_scale 1.0
settings_put global transition_animation_scale 1.0
settings_put global animator_duration_scale 1.0
log_p "Animation scales set to 1.0 (levels are static, see system.prop)"

settings_put system tran_dc_dimming_enable $(cfg_bool display_dc true)
settings_put system tran_display_color_enhance $(cfg_bool display_color true)
settings_put system tran_reading_mode_enable $(cfg_bool display_reading false)
resetprop ro.tran.display_hdr_support $(cfg_bool display_hdr true)
resetprop ro.tran.display_dc_dimming_support $(cfg_bool display_dc true)
log_p "Display settings written"

resetprop ro.aod_alwaysshow_support $(cfg_bool aod true)
log_p "AOD = $(cfg_bool aod true)"

GM=$(cfg_bool game_master true)
resetprop ro.os_game_tp_esports10.support "$GM"
if [ "$GM" = "1" ]; then
    resetprop ro.os_game_ray_tracing.support $(cfg_bool game_raytracing true)
    resetprop ro.os_game_frame_game_interpolation.support $(cfg_bool game_interpolation true)
    resetprop ro.os_game_graphic_hdr.support $(cfg_bool game_hdr true)
    resetprop ro.os_game_bypass_charging_support $(cfg_bool game_bypass_charge false)
else
    resetprop ro.os_game_ray_tracing.support 0
    resetprop ro.os_game_frame_game_interpolation.support 0
    resetprop ro.os_game_graphic_hdr.support 0
    resetprop ro.os_game_bypass_charging_support 0
fi
log_p "Game mode = $GM"

resetprop ro.sys.tran.ai_subtitles_support $(cfg_bool ai_subtitles true)
resetprop ro.sys.tran.aiphone_summary_support $(cfg_bool ai_call_summary true)
resetprop ro.os_soundrecorder_speech_support $(cfg_bool ai_sound_rec true)
log_p "AI props applied"

log_p "Boot sound / anim / emoji font handled in post-fs-data.sh"

resetprop ro.tran.charge_animation_support $(cfg_bool charge_anim true)
log_p "Charging anim = $(cfg_bool charge_anim true)"

resetprop ro.tranos_hidenavigationbar_support $(cfg_bool nav_hide false)
log_p "Nav hide = $(cfg_bool nav_hide false)"

log_p "=== TransFlagship V3.16 service complete ==="
