#!/system/bin/sh
# Parallel motion = platform_level 3 whenever Parallel is on.
# Flagship glass = unionrender / liquid glass / compositor (blur 2/3).
# Level 1 must not drop platform_level (that made Parallel become basic).

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"

os16_cfg_bool() {
  k="$1"; d="$2"
  [ -f "$CFG" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

os16_cfg_int() {
  k="$1"; d="$2"
  v=$(os16_cfg_bool "$k" "$d")
  case "$v" in
    ''|*[!0-9]*) echo "$d" ;;
    *) echo "$v" ;;
  esac
}

os16_rp() {
  k="$1"; v="$2"
  if [ -x /data/adb/ksud ]; then
    /data/adb/ksud resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if [ -x /data/adb/ksu/bin/resetprop ]; then
    /data/adb/ksu/bin/resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    /data/adb/ksu/bin/resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if [ -x /data/adb/magisk/resetprop ]; then
    /data/adb/magisk/resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    /data/adb/magisk/resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if command -v resetprop >/dev/null 2>&1; then
    resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  setprop "$k" "$v" >/dev/null 2>&1
}

os16_rp_overwrite() {
  k="$1"; v="$2"
  if [ -x /data/adb/magisk/resetprop ]; then
    /data/adb/magisk/resetprop --delete "$k" >/dev/null 2>&1
  fi
  if command -v resetprop >/dev/null 2>&1; then
    resetprop --delete "$k" >/dev/null 2>&1
  fi
  if [ -x /data/adb/ksud ]; then
    /data/adb/ksud resetprop --delete "$k" >/dev/null 2>&1
  fi
  os16_rp "$k" "$v"
}

os16_settings_put() {
  ns="$1"; k="$2"; v="$3"
  settings put "$ns" "$k" "$v" >/dev/null 2>&1
}

os16_blur_vals() {
  anim=$(os16_cfg_bool anim_os16 true)
  on=$(os16_cfg_bool blur_os16 true)
  lvl=$(os16_cfg_int blur_os16_level 2)
  [ "$lvl" -ge 1 ] 2>/dev/null || lvl=2
  [ "$lvl" -le 3 ] 2>/dev/null || lvl=2

  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    BLVL=$lvl
    EN=1
    case "$lvl" in
      1) RAD=20 ;;
      3) RAD=80 ;;
      *) RAD=45 ;;
    esac
  else
    BLVL=0
    EN=0
    RAD=0
    lvl=0
  fi

  # Parallel motion always uses platform 3 when Parallel is on.
  # Glass is unionrender / liquid glass / compositor, not platform_level.
  GLASS=0
  if [ "$anim" = "true" ] || [ "$anim" = "1" ]; then
    A01=1
    ALVL=3
  else
    A01=0
    ALVL=0
  fi
  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    if [ "$lvl" -ge 2 ]; then
      GLASS=1
    fi
  fi

  if [ "$GLASS" = "1" ]; then
    B01=1
    SFDIS=0
    DIS=0
    EXP=0
  else
    B01=0
    SFDIS=1
    DIS=1
    EXP=1
  fi
  BLUR_ON=$on
  BLUR_LVL=$lvl
  ANIM_ON=$anim
}

os16_apply_blur_props() {
  os16_blur_vals
  os16_rp_overwrite ro.tr_animation.platform_level "$ALVL"
  os16_rp_overwrite ro.tr_perf.launch_start_exit.model "$ALVL"
  os16_rp_overwrite ro.tr_perf.power_keyguard_animation.model "$ALVL"
  os16_rp_overwrite ro.tr_perf.recent_animation.model "$ALVL"
  os16_rp_overwrite ro.tr_perf.unlock_mode.model "$ALVL"
  os16_rp ro.tr_dynamicbar.support "$A01"
  os16_rp ro.tr_livewallpaper.dreamanimation.support "$A01"
  os16_rp ro.tr_multiwindow.anim_arc.support "$A01"
  os16_rp ro.transsion_async_animation_support "$A01"
  os16_rp ro.transsion_unlock_mode_support "$ALVL"
  os16_rp ro.transsion_launch_start_exit_support "$ALVL"
  os16_rp ro.transsion_power_keyguard_animation_support "$ALVL"
  os16_rp ro.transsion.recent_animation.model "$ALVL"
  os16_rp_overwrite ro.tran_display_unionrender.support "$B01"
  os16_rp_overwrite ro.tr_display.liquidglass.support "$B01"
  os16_rp_overwrite ro.surface_flinger.supports_background_blur "$B01"
  os16_rp_overwrite ro.os.recent.blur "$B01"
  os16_rp ro.transsion_launcher_gaussian_blur_support "$BLVL"
  os16_rp tr_launcher.gaussianblur.support "$BLVL"
  os16_rp ro.tran.effectengine.dynamicblur.support "$B01"
  os16_rp ro.os_xos16_blur_v2_support "$B01"
  os16_rp persist.sys.sf.disable_blurs "$SFDIS"
  os16_rp persist.sys.disable_blur "$DIS"
  os16_rp persist.sysui.disableBlur "$SFDIS"
  os16_rp persist.sysui.disable_blur "$SFDIS"
  os16_rp ro.sf.blurs_are_expensive "$EXP"
}

os16_apply_social_props() {
  smaster=$(os16_cfg_bool social_master true)
  if [ "$smaster" = "true" ] || [ "$smaster" = "1" ]; then
    smode=1
    sdefoff=0
    srec_raw=$(os16_cfg_bool social_record true)
    strans_raw=$(os16_cfg_bool social_translate true)
    sbeau_raw=$(os16_cfg_bool social_beauty true)
    srec=1; strans=1; sbeau=1
    [ "$srec_raw" = "false" ] || [ "$srec_raw" = "0" ] && srec=0
    [ "$strans_raw" = "false" ] || [ "$strans_raw" = "0" ] && strans=0
    [ "$sbeau_raw" = "false" ] || [ "$sbeau_raw" = "0" ] && sbeau=0
  else
    smode=0
    sdefoff=1
    srec=0
    strans=0
    sbeau=0
  fi
  if [ "$sbeau" = "1" ]; then
    sbeau_dis=0
  else
    sbeau_dis=1
  fi
  # GT dump has these in /tr_product/etc/build.prop — Magisk system.prop loses.
  os16_rp_overwrite ro.tr_social.turbo_mode.support "$smode"
  os16_rp_overwrite ro.tr_social.record.support "$srec"
  os16_rp_overwrite ro.tr_social.call_translator.support "$strans"
  os16_rp_overwrite ro.tr_social.call_summary.support "$strans"
  os16_rp_overwrite ro.tr_social.sound_change.support "$srec"
  os16_rp_overwrite ro.tr_socialturbo.makeup.support "$sbeau"
  os16_rp_overwrite ro.tr_social.beauty_disable.support "$sbeau_dis"
  os16_rp_overwrite ro.tr_social.default_off.support "$sdefoff"
}

os16_cfg_01() {
  k="$1"; d="$2"
  v=$(os16_cfg_bool "$k" "$d")
  if [ "$v" = "false" ] || [ "$v" = "0" ]; then
    echo 0
  else
    echo 1
  fi
}

os16_apply_display_props() {
  hdr=$(os16_cfg_01 display_hdr true)
  col=$(os16_cfg_01 display_color true)
  # GT dump has sdr2hdr/xdr at 0 in /tr_product/etc/build.prop.
  os16_rp_overwrite ro.tr_display.sdr2hdr.support "$hdr"
  os16_rp_overwrite ro.tr_light.xdr.support "$hdr"
  os16_rp_overwrite ro.tr_light.xdr.v2.support "$hdr"
  os16_rp_overwrite ro.tr_display.colormode.feature.support "$col"
  os16_rp_overwrite ro.tr_display.color.temperature.feature.support "$col"
  os16_rp persist.tr_display.color.temperature.aosp.support "$col"
  # V1.53: OS 16 keys stuck, Settings unchanged. Flagship 15 gated
  # Display rows on these names (not in the GT tr_product dump).
  os16_rp_overwrite ro.tran.display_hdr_support "$hdr"
  dc=$(os16_cfg_01 display_dc true)
  os16_rp_overwrite ro.tran.display_dc_dimming_support "$dc"
}

os16_apply_display_settings() {
  dc=$(os16_cfg_01 display_dc true)
  col=$(os16_cfg_01 display_color true)
  hdr=$(os16_cfg_01 display_hdr true)
  # Reading default is off (same as Flagship 15).
  rd=$(os16_cfg_bool display_reading false)
  if [ "$rd" = "true" ] || [ "$rd" = "1" ]; then
    rd=1
  else
    rd=0
  fi
  os16_settings_put system tran_dc_dimming_enable "$dc"
  os16_settings_put global tran_dc_dimming_enable "$dc"
  os16_settings_put system tran_display_color_enhance "$col"
  os16_settings_put global tran_display_color_enhance "$col"
  os16_settings_put system tran_reading_mode_enable "$rd"
  os16_settings_put global tran_reading_mode_enable "$rd"
  os16_settings_put system tr_dc_dimming_enable "$dc"
  os16_settings_put global tr_dc_dimming_enable "$dc"
  os16_settings_put system tr_display_color_enhance "$col"
  os16_settings_put global tr_display_color_enhance "$col"
  os16_settings_put system tr_reading_mode_enable "$rd"
  os16_settings_put global tr_reading_mode_enable "$rd"
  os16_settings_put system tran_sdr2hdr_enable "$hdr"
  os16_settings_put global tran_sdr2hdr_enable "$hdr"
  am force-stop com.android.settings >/dev/null 2>&1
}

os16_force_stop_launchers() {
  home=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1)
  home_pkg=$(echo "$home" | cut -d/ -f1)
  for pkg in \
      "$home_pkg" \
      com.transsion.launcher3 \
      com.transsion.XOSLauncher \
      com.transsion.hilauncher \
      com.transsion.launcher \
      com.android.launcher3
  do
    [ -n "$pkg" ] || continue
    am force-stop "$pkg" >/dev/null 2>&1
  done
}

os16_restart_systemui() {
  am crash com.android.systemui >/dev/null 2>&1
  killall com.android.systemui >/dev/null 2>&1
}

os16_restart_surfaceflinger() {
  setprop ctl.restart surfaceflinger >/dev/null 2>&1
  stop surfaceflinger >/dev/null 2>&1
  start surfaceflinger >/dev/null 2>&1
  killall surfaceflinger >/dev/null 2>&1
}

os16_apply_blur_runtime() {
  os16_blur_vals
  os16_settings_put global disable_window_blurs "$DIS"
  os16_settings_put system disable_window_blurs "$DIS"
  settings delete secure accessibility_reduce_transparency >/dev/null 2>&1
  os16_settings_put global transsion_launcher_gaussian_blur_support "$BLVL"
  os16_settings_put system transsion_launcher_gaussian_blur_support "$BLVL"
  os16_settings_put global transsion_launcher_gaussian_support "$BLVL"
  os16_settings_put system transsion_launcher_gaussian_support "$BLVL"
  if [ "$GLASS" = "1" ]; then
    os16_settings_put global transsion_launcher_gaussian_blur_enable "$EN"
    os16_settings_put system transsion_launcher_gaussian_blur_enable "$EN"
    os16_settings_put global transsion_launcher_blur_radius "$RAD"
    os16_settings_put system transsion_launcher_blur_radius "$RAD"
  else
    os16_settings_put global transsion_launcher_gaussian_blur_enable 0
    os16_settings_put system transsion_launcher_gaussian_blur_enable 0
    settings delete system transsion_launcher_blur_radius >/dev/null 2>&1
    settings delete global transsion_launcher_blur_radius >/dev/null 2>&1
  fi
  wm disable-blur "$DIS" >/dev/null 2>&1
  cmd window disable-blur "$DIS" >/dev/null 2>&1
  device_config put systemui notification_shade_blur "$([ "$GLASS" = "1" ] && echo true || echo false)" >/dev/null 2>&1
  os16_force_stop_launchers
}

if [ "${0##*/}" = "apply_blur.sh" ]; then
  mode="${1:-all}"
  case "$mode" in
    props) os16_apply_blur_props; os16_apply_social_props; os16_apply_display_props ;;
    runtime) os16_apply_blur_runtime; os16_apply_display_settings; os16_restart_systemui ;;
    social) os16_apply_social_props ;;
    display) os16_apply_display_props; os16_apply_display_settings ;;
    *)
      os16_apply_blur_props
      os16_apply_social_props
      os16_apply_display_props
      os16_apply_display_settings
      os16_apply_blur_runtime
      os16_restart_surfaceflinger
      ;;
  esac
fi
