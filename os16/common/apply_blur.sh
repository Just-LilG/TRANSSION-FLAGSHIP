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
  # Same path Flagship 15 used on this X6886 (content + settings).
  content update --uri content://settings/"$ns" \
    --bind value:s:"$v" \
    --where "name='$k'" >/dev/null 2>&1
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

os16_cfg_01() {
  k="$1"; d="$2"
  v=$(os16_cfg_bool "$k" "$d")
  if [ "$v" = "false" ] || [ "$v" = "0" ]; then
    echo 0
  else
    echo 1
  fi
}

os16_vconfig_nsenter() {
  if [ -x /system/bin/nsenter ]; then
    echo "/system/bin/nsenter -t 1 -m --"
  elif command -v nsenter >/dev/null 2>&1; then
    echo "nsenter -t 1 -m --"
  fi
}

os16_bind_file() {
  src="$1"
  dest="$2"
  [ -f "$src" ] || return 1
  NS=$(os16_vconfig_nsenter)
  parent=$(dirname "$dest")
  if [ ! -d "$parent" ]; then
    mkdir -p "$parent" 2>/dev/null
    [ -n "$NS" ] && $NS mkdir -p "$parent" 2>/dev/null
  fi
  [ -d "$parent" ] || return 1
  if [ ! -e "$dest" ]; then
    touch "$dest" 2>/dev/null
    [ -e "$dest" ] || { [ -n "$NS" ] && $NS touch "$dest" 2>/dev/null; }
  fi
  [ -e "$dest" ] || return 1
  chcon --reference="$dest" "$src" 2>/dev/null
  chmod 644 "$src" 2>/dev/null
  if [ -n "$NS" ]; then
    $NS umount -l "$dest" 2>/dev/null
    $NS mount --bind "$src" "$dest" && return 0
  fi
  umount -l "$dest" 2>/dev/null
  mount --bind "$src" "$dest"
}

os16_vconfig_upsert() {
  f="$1"
  k="$2"
  v="$3"
  [ -f "$f" ] || : > "$f"
  if grep -q "^${k}=" "$f" 2>/dev/null; then
    sed -i "s|^${k}=.*|${k}=${v}|" "$f"
  else
    printf '%s=%s\n' "$k" "$v" >> "$f"
  fi
}

os16_bind_vconfig_pkg() {
  staged="$1"
  pkg="$2"
  [ -f "$staged" ] || return 1
  mkdir -p "$MODDIR/system/tr_product/etc/vconfig/$pkg"
  cp -f "$staged" "$MODDIR/system/tr_product/etc/vconfig/$pkg/build.prop"
  chmod 644 "$MODDIR/system/tr_product/etc/vconfig/$pkg/build.prop" 2>/dev/null
  for dest in \
    /tr_product/etc/vconfig/$pkg/build.prop \
    /system/tr_product/etc/vconfig/$pkg/build.prop \
    /product/etc/vconfig/$pkg/build.prop \
    /system/product/etc/vconfig/$pkg/build.prop
  do
    os16_bind_file "$staged" "$dest"
  done
}

os16_seed_vconfig_pkg() {
  pkg="$1"
  staged="$MODDIR/vconfig/$pkg/build.prop"
  mkdir -p "$(dirname "$staged")"
  if [ ! -s "$staged" ]; then
    dest=""
    for p in \
      /tr_product/etc/vconfig/$pkg/build.prop \
      /system/tr_product/etc/vconfig/$pkg/build.prop \
      /product/etc/vconfig/$pkg/build.prop
    do
      if [ -f "$p" ]; then
        dest="$p"
        break
      fi
    done
    if [ -n "$dest" ]; then
      cat "$dest" > "$staged"
    else
      : > "$staged"
    fi
  fi
  echo "$staged"
}

os16_apply_aod_vconfig() {
  aod=$(os16_cfg_01 aod_os16 true)
  staged=$(os16_seed_vconfig_pkg com.transsion.aod)
  # GT X6858 dump: /tr_product/etc/vconfig/com.transsion.aod/build.prop
  #   tr_aod.always.show.feature.support=1
  #   tr_aod.horizontal.display.feature.support=1
  # That is Always Show AOD. Magisk system.prop never reaches this file.
  os16_vconfig_upsert "$staged" "tr_aod.always.show.feature.support" "$aod"
  os16_vconfig_upsert "$staged" "tr_aod.horizontal.display.feature.support" "$aod"
  os16_bind_vconfig_pkg "$staged" com.transsion.aod
}

os16_apply_launcher_vconfig() {
  bar=$(os16_cfg_01 dynamicbar_os16 true)
  staged=$(os16_seed_vconfig_pkg com.transsion.launcher3)
  # Flagship 15 XOS 16 wrote this into launcher3 vconfig, not only system.prop.
  os16_vconfig_upsert "$staged" "ro.os.tran_hide_status_bar_for_land_recent" "$bar"
  os16_bind_vconfig_pkg "$staged" com.transsion.launcher3
}

os16_apply_settings_vconfig() {
  on=$(os16_cfg_bool scale_os16 true)
  if [ "$on" = "true" ] || [ "$on" = "1" ]; then val=true; else val=false; fi
  staged=$(os16_seed_vconfig_pkg com.android.settings)
  # GT X6858: /tr_product/etc/vconfig/com.android.settings/build.prop
  #   tr_display.resolution.scalingup.support=true
  os16_vconfig_upsert "$staged" "tr_display.resolution.scalingup.support" "$val"
  os16_bind_vconfig_pkg "$staged" com.android.settings
  os16_rp_overwrite tr_display.resolution.scalingup.support "$val"
  os16_rp_overwrite ro.tr_display.resolution.scalingup.support "$val"
}

os16_rp_pair() {
  k="$1"
  v="$2"
  os16_rp_overwrite "$k" "$v"
  case "$k" in
    ro.*) ;;
    *) os16_rp_overwrite "ro.$k" "$v" ;;
  esac
}

os16_vconfig_pkg_keys() {
  pkg="$1"
  shift
  staged=$(os16_seed_vconfig_pkg "$pkg")
  while [ $# -ge 2 ]; do
    os16_vconfig_upsert "$staged" "$1" "$2"
    os16_rp_pair "$1" "$2"
    shift 2
  done
  os16_bind_vconfig_pkg "$staged" "$pkg"
}

os16_apply_gt_apps_vconfig() {
  on=$(os16_cfg_bool gt_apps_os16 true)
  [ "$on" = "true" ] || [ "$on" = "1" ] || return 0
  # GT X6858 app vconfigs (Settings scale did not unhide Display). Skip dump 0s
  # (3d photo, Camon-only motions, PC extend-screen, IoT Go).
  os16_vconfig_pkg_keys com.gallery20 \
    tr_gallery.custom.fliters.support 1 \
    tr_gallery.drag.sort.support 1 \
    tr_gallery.easypic.support 1 \
    tr_gallery.matting.support 1 \
    tr_gallery.photo.16grid.support 1 \
    tr_gallery.photo.8grid.support 1 \
    tr_gallery.photo.cover.support 1 \
    tr_gallery.photo.feature.support 1 \
    tr_gallery.search.support 1 \
    tr_gallery.soft.player.support 1
  os16_vconfig_pkg_keys com.transsion.soundrecorder \
    tr_soundrecorder.speech.feature.support 1
  os16_vconfig_pkg_keys com.transsion.scanningrecharger \
    tr_smartscan.ar_measure.support true \
    tr_smartscan.document_scan.support true \
    tr_smartscan.medicine_verification.support true \
    tr_smartscan.recharge.support true
  os16_vconfig_pkg_keys com.transsion.microintelligence \
    tr_microIntelligence.gesture_functions.feature.support 1
  os16_vconfig_pkg_keys com.transsion.pcconnect \
    tr_pcconnect.backup.feature.support 1 \
    tr_pcconnect.gesture_file_transfer.feature.support 1 \
    tr_pcconnect.network_sharing.feature.support 1 \
    tr_pcconnect.pc_mouse_button.feature.support 1
  os16_vconfig_pkg_keys com.transsion.personalizedService \
    tr_zeroscreen.ai.card.support 1
  os16_vconfig_pkg_keys com.transsion.globalsearch \
    tr_globalsearch.easypic.support 1
  os16_vconfig_pkg_keys com.transsion.smartpanel \
    ro.tr_smartpanel.os_slider_panel_default_close.config 0 \
    ro.tr_smartpanel.os_smart_hub_def_off.config 0
  os16_vconfig_pkg_keys com.sh.smart.caller \
    ro.tr_dialer.contact.carlcare.feature.support 1
  os16_rp_overwrite ro.tr_smartpanel.os_smartpanel.support 1
  os16_rp_overwrite ro.tr_smartpanel.os_slider_panel.support 1
  os16_rp_overwrite ro.tr_pcconnect.feature.support 1
  os16_rp_overwrite ro.tr_pcconnect.backup.feature.support 1
  os16_rp_overwrite ro.tr_microIntelligence.microIntelligence.feature.support 1
  os16_rp_overwrite ro.tr_microIntelligence.gesture_functions.feature.support 1
  os16_rp_overwrite ro.tr_soundrecorder.summary.feature.support 1
}

os16_apply_gt_apps_runtime() {
  on=$(os16_cfg_bool gt_apps_os16 true)
  [ "$on" = "true" ] || [ "$on" = "1" ] || return 0
  for pkg in \
      com.gallery20 \
      com.transsion.gallery \
      com.transsion.gallery3d \
      com.transsion.soundrecorder \
      com.transsion.scanningrecharger \
      com.transsion.smartscan \
      com.transsion.scanner \
      com.transsion.microintelligence \
      com.transsion.pcconnect \
      com.transsion.connectx \
      com.transsion.personalizedService \
      com.transsion.zeroscreen \
      com.transsion.globalsearch \
      com.transsion.smartpanel \
      com.sh.smart.caller \
      com.transsion.phonemaster
  do
    am force-stop "$pkg" >/dev/null 2>&1
  done
}

os16_apply_aod_props() {
  aod=$(os16_cfg_01 aod_os16 true)
  os16_rp_overwrite ro.tr_aod.feature.support "$aod"
  os16_rp_overwrite ro.tr_aod.doze.brightness.feature.support "$aod"
  os16_rp_overwrite ro.tr_aod.half.screen.feature.support "$aod"
  os16_rp_overwrite tr_aod.horizontal.display.feature.support "$aod"
  os16_rp_overwrite ro.tr_aod.horizontal.display.feature.support "$aod"
  os16_rp_overwrite tr_aod.always.show.feature.support "$aod"
  os16_rp_overwrite ro.tr_aod.always.show.feature.support "$aod"
  os16_rp_overwrite ro.aod_alwaysshow_support "$aod"
  os16_rp_overwrite ro.tran_aod_v3_support "$aod"
  os16_rp_overwrite ro.tran_doze_brightness_support "$aod"
  os16_apply_aod_vconfig
}

os16_apply_aod_settings() {
  aod=$(os16_cfg_01 aod_os16 true)
  os16_settings_put secure doze_always_on "$aod"
  os16_settings_put secure doze_enabled 1
  os16_settings_put system doze_always_on "$aod"
  os16_settings_put global doze_always_on "$aod"
  os16_settings_put system tran_aod_enable "$aod"
  os16_settings_put global tran_aod_enable "$aod"
  os16_settings_put system tr_aod_enable "$aod"
  os16_settings_put global tr_aod_enable "$aod"
  am force-stop com.transsion.aod >/dev/null 2>&1
  am force-stop com.android.settings >/dev/null 2>&1
}

os16_apply_dynamicbar_props() {
  bar=$(os16_cfg_01 dynamicbar_os16 true)
  os16_rp_overwrite ro.tr_dynamicbar.support "$bar"
  os16_rp_overwrite ro.os_dynamicbar_ai_translation_support "$bar"
  os16_rp_overwrite ro.tran_hios_dynamic_bar_support "$bar"
  # This support flag unhides Settings → Dynamic Bar → Always Show Background.
  # V1.59 set it to 0 and hid the row. The Settings toggle (not this prop)
  # is what should turn the empty pill off.
  os16_rp_overwrite ro.os_dynamic_bar_resident_plane_support "$bar"
  # Flagship 15 extra: hide the landscape-recents status-bar overlay (empty
  # pill / "bug not a feature" in recents). Same key as TransFlagship 15.
  os16_rp_overwrite ro.os.tran_hide_status_bar_for_land_recent "$bar"
  os16_apply_launcher_vconfig
}

os16_apply_dynamicbar_runtime() {
  # V1.59 wrote fake always-show=0 settings and crashed SystemUI (boot reboot +
  # hid Always Show). Drop those leftovers. Do not crash SystemUI.
  for ns in system global secure; do
    settings delete "$ns" os_dynamic_bar_resident_plane >/dev/null 2>&1
    settings delete "$ns" island_always_show_background >/dev/null 2>&1
    settings delete "$ns" tran_dynamic_bar_always_show >/dev/null 2>&1
  done
}

os16_clear_failed_feature_leftovers() {
  # V1.52–1.55 Social Turbo / Display extras never unhid OS 16 UI.
  for ns in system global; do
    settings delete "$ns" tran_dc_dimming_enable >/dev/null 2>&1
    settings delete "$ns" tran_display_color_enhance >/dev/null 2>&1
    settings delete "$ns" tran_reading_mode_enable >/dev/null 2>&1
    settings delete "$ns" tr_dc_dimming_enable >/dev/null 2>&1
    settings delete "$ns" tr_display_color_enhance >/dev/null 2>&1
    settings delete "$ns" tr_reading_mode_enable >/dev/null 2>&1
    settings delete "$ns" tran_sdr2hdr_enable >/dev/null 2>&1
  done
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
  # Do not am crash / killall SystemUI. V1.59 did that at boot and the phone
  # came up then cold-rebooted.
  :
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
    props) os16_apply_blur_props; os16_apply_aod_props; os16_apply_settings_vconfig; os16_apply_gt_apps_vconfig; os16_apply_dynamicbar_props ;;
    runtime) os16_apply_blur_runtime; os16_apply_aod_settings; os16_apply_gt_apps_runtime; os16_apply_dynamicbar_runtime ;;
    *)
      os16_apply_blur_props
      os16_apply_aod_props
      os16_apply_settings_vconfig
      os16_apply_gt_apps_vconfig
      os16_apply_dynamicbar_props
      os16_clear_failed_feature_leftovers
      os16_apply_aod_settings
      os16_apply_gt_apps_runtime
      os16_apply_dynamicbar_runtime
      os16_apply_blur_runtime
      os16_restart_surfaceflinger
      ;;
  esac
fi
