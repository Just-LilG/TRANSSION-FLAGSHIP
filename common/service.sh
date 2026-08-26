#!/system/bin/sh

MODDIR="/data/adb/modules/transsion-flagship"
CFG="$MODDIR/config.json"
ACTIVE="$MODDIR/device_active.txt"
LOG="$MODDIR/transflagship_service.log"

rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_p "=== TransFlagship V4.21-beta2 diagnostic header ==="
log_p "Device model    : $(getprop ro.product.model 2>/dev/null)"
log_p "Device marketname: $(getprop ro.product.marketname 2>/dev/null)"
log_p "Brand           : $(getprop ro.product.brand 2>/dev/null)"
log_p "Android release : $(getprop ro.build.version.release 2>/dev/null)"
log_p "Android SDK     : $(getprop ro.build.version.sdk 2>/dev/null)"
log_p "Build desc      : $(getprop ro.build.description 2>/dev/null)"
log_p "ro.tran.os.type : $(getprop ro.tran.os.type 2>/dev/null)"
log_p "ro.transsion.os.version: $(getprop ro.transsion.os.version 2>/dev/null)"
log_p "SELinux         : $(getenforce 2>/dev/null)"
log_p "Module dir      : $MODDIR"
log_p "Module dir exists: $([ -d "$MODDIR" ] && echo yes || echo no)"
log_p "system.prop present: $([ -f "$MODDIR/system.prop" ] && echo yes || echo no)"
if [ -f "$MODDIR/system.prop" ]; then
    log_p "system.prop line count: $(wc -l < "$MODDIR/system.prop")"
fi
log_p "config.json present: $([ -f "$CFG" ] && echo yes || echo no)"
log_p "--- Install-time detection (from install.sh, captured once at flash) ---"
if [ -f "$MODDIR/install_diagnostic.txt" ]; then
    while IFS= read -r line; do log_p "$line"; done < "$MODDIR/install_diagnostic.txt"
else
    log_p "install_diagnostic.txt missing — module may predate this diagnostic or install.sh failed before writing it"
fi
log_p "--- Spot-check live props (should be 1/true if module is active) ---"
log_p "ro.transsion_unlock_mode_support = $(getprop ro.transsion_unlock_mode_support 2>/dev/null)"
log_p "ro.transsion_launch_start_exit_support = $(getprop ro.transsion_launch_start_exit_support 2>/dev/null)"
log_p "ro.aod_alwaysshow_support = $(getprop ro.aod_alwaysshow_support 2>/dev/null)"
log_p "ro.os_game_tp_esports20.support = $(getprop ro.os_game_tp_esports20.support 2>/dev/null)"
log_p "=== end diagnostic header ==="
log_p ""

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

FORCE_120HZ=$(cfg_bool force_120hz false)
if [ "$FORCE_120HZ" = "1" ]; then
    settings_put system tran_refresh_mode 120
    settings_put system tran_need_recovery_refresh_mode 120
    settings_put system tran_need_recovery_refresh_rate 120
    settings_put system last_tran_refresh_mode_in_refresh_setting 120
    settings_put system peak_refresh_rate 120.0
    settings_put system min_refresh_rate 120.0
fi
log_p "Force 120Hz = $FORCE_120HZ"

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

BLUR_ON=$(cfg_bool launcher_blur true)
if [ "$BLUR_ON" = "1" ]; then
    resetprop ro.transsion_launcher_gaussian_blur_support 2
    resetprop tr_launcher.gaussianblur.support 2
    resetprop ro.tran.effectengine.dynamicblur.support 1
else
    resetprop ro.transsion_launcher_gaussian_blur_support 0
    resetprop tr_launcher.gaussianblur.support 0
    resetprop ro.tran.effectengine.dynamicblur.support 0
fi
settings_put system transsion_launcher_gaussian_blur_enable "$BLUR_ON"
am force-stop com.transsion.launcher3 2>/dev/null
log_p "Launcher blur (incl. dock) = $BLUR_ON (launcher restarted to apply)"

PERF_TUNING_ON=$(cfg_bool perf_tuning false)
if [ "$PERF_TUNING_ON" = "1" ]; then
    resetprop ro.tr_animation.platform_level 3
    resetprop ro.tr_perf.launch_start_exit.model 3
    resetprop ro.tr_perf.power_keyguard_animation.model 3
    resetprop ro.tr_perf.recent_animation.model 3
    resetprop ro.tr_perf.unlock_mode.model 3
    resetprop ro.tran_display_unionrender.support 1
    resetprop ro.tr_dynamicbar.support 1
fi
log_p "Experimental performance tuning = $PERF_TUNING_ON"

log_p "Boot sound / anim / emoji font handled in post-fs-data.sh"

CA_ON=$(cfg_bool charge_anim true)
resetprop ro.tran.charge_animation_support "$CA_ON"
resetprop ro.tran.lockscreen_charge_anim "$CA_ON"
am force-stop com.transsion.aichargeprovider 2>/dev/null
log_p "Charging anim = $CA_ON"

resetprop ro.tranos_hidenavigationbar_support $(cfg_bool nav_hide false)
log_p "Nav hide = $(cfg_bool nav_hide false)"

log_p "=== TransFlagship V4.21-beta2 service complete ==="
