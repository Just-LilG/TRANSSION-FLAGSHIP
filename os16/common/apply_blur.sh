#!/system/bin/sh
# Flagship 16 blur apply. Stock OS 16 sets ro.tr_display.liquidglass.support=1
# in /tr_product/etc/build.prop. Magisk system.prop loses to that overlay for
# keys that already exist. resetprop after overlay (and again at late_start)
# is what actually changes live getprop. Do not resetprop AI/game keys here.

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

os16_settings_put() {
  ns="$1"; k="$2"; v="$3"
  settings put "$ns" "$k" "$v" >/dev/null 2>&1
}

os16_blur_vals() {
  on=$(os16_cfg_bool blur_os16 true)
  lvl=$(os16_cfg_int blur_os16_level 2)
  [ "$lvl" -ge 1 ] 2>/dev/null || lvl=2
  [ "$lvl" -le 3 ] 2>/dev/null || lvl=2
  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    B01=1
    BLVL=$lvl
    SFDIS=0
    EN=1
    DIS=0
    EXP=0
    case "$lvl" in
      1) RAD=20 ;;
      3) RAD=80 ;;
      *) RAD=45 ;;
    esac
  else
    B01=0
    BLVL=0
    SFDIS=1
    EN=0
    DIS=1
    EXP=1
    RAD=0
    lvl=0
  fi
  BLUR_ON=$on
  BLUR_LVL=$lvl
}

os16_apply_blur_props() {
  os16_blur_vals
  os16_rp ro.tr_display.liquidglass.support "$B01"
  os16_rp ro.surface_flinger.supports_background_blur "$B01"
  os16_rp ro.os.recent.blur "$B01"
  os16_rp ro.transsion_launcher_gaussian_blur_support "$BLVL"
  os16_rp tr_launcher.gaussianblur.support "$BLVL"
  os16_rp ro.tran.effectengine.dynamicblur.support "$B01"
  os16_rp ro.os_xos16_blur_v2_support "$B01"
  os16_rp persist.sys.sf.disable_blurs "$SFDIS"
  os16_rp persist.sys.disable_blur "$DIS"
  os16_rp ro.sf.blurs_are_expensive "$EXP"
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

os16_apply_blur_runtime() {
  os16_blur_vals
  os16_settings_put global disable_window_blurs "$DIS"
  os16_settings_put system disable_window_blurs "$DIS"
  os16_settings_put global transsion_launcher_gaussian_blur_enable "$EN"
  os16_settings_put system transsion_launcher_gaussian_blur_enable "$EN"
  os16_settings_put global transsion_launcher_gaussian_blur_support "$BLVL"
  os16_settings_put system transsion_launcher_gaussian_blur_support "$BLVL"
  os16_settings_put global transsion_launcher_blur_radius "$RAD"
  os16_settings_put system transsion_launcher_blur_radius "$RAD"
  os16_settings_put global transsion_launcher_gaussian_support "$BLVL"
  os16_settings_put system transsion_launcher_gaussian_support "$BLVL"
  wm disable-blur "$DIS" >/dev/null 2>&1
  cmd window disable-blur "$DIS" >/dev/null 2>&1
  os16_force_stop_launchers
}

# When this file is executed (WebUI Apply), not when sourced.
if [ "${0##*/}" = "apply_blur.sh" ]; then
  mode="${1:-all}"
  case "$mode" in
    props) os16_apply_blur_props ;;
    runtime) os16_apply_blur_runtime ;;
    *)
      os16_apply_blur_props
      os16_apply_blur_runtime
      ;;
  esac
fi
