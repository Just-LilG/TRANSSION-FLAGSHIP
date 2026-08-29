#!/system/bin/sh
# Shared by post-fs-data.sh and service.sh. No WebUI.

MODDIR="${MODDIR:-${0%/*}}"
LOG="$MODDIR/lab.log"

lab_log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

lab_combo() {
  f="$MODDIR/combo"
  n=5
  if [ -f "$f" ]; then
    n=$(grep -oE '[1-6]' "$f" | head -1)
  fi
  [ -n "$n" ] || n=5
  echo "$n"
}

lab_rp() {
  k="$1"; v="$2"
  if [ -x /data/adb/magisk/resetprop ]; then
    /data/adb/magisk/resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    /data/adb/magisk/resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if command -v resetprop >/dev/null 2>&1; then
    resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if [ -x /data/adb/ksud ]; then
    /data/adb/ksud resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  setprop "$k" "$v" >/dev/null 2>&1
}

lab_set() {
  settings put "$1" "$2" "$3" >/dev/null 2>&1
}

lab_ns() {
  if [ -x /system/bin/nsenter ]; then
    echo "/system/bin/nsenter -t 1 -m --"
  elif command -v nsenter >/dev/null 2>&1; then
    echo "nsenter -t 1 -m --"
  fi
}

lab_bind() {
  src="$1"; dest="$2"
  [ -f "$src" ] || return 1
  [ -e "$dest" ] || return 1
  NS=$(lab_ns)
  chcon --reference="$dest" "$src" 2>/dev/null
  chmod 644 "$src" 2>/dev/null
  if [ -n "$NS" ]; then
    $NS umount -l "$dest" 2>/dev/null
    $NS mount --bind "$src" "$dest" && return 0
  fi
  umount -l "$dest" 2>/dev/null
  mount --bind "$src" "$dest"
}

lab_upsert() {
  f="$1"; k="$2"; v="$3"
  [ -f "$f" ] || : > "$f"
  if grep -q "^${k}=" "$f" 2>/dev/null; then
    sed -i "s|^${k}=.*|${k}=${v}|" "$f"
  else
    printf '%s=%s\n' "$k" "$v" >> "$f"
  fi
}

# Shade / compositor / liquid glass (the set that already works on X6886).
lab_shade() {
  lab_rp ro.tr_animation.platform_level 3
  lab_rp ro.tr_display.liquidglass.support 1
  lab_rp ro.surface_flinger.supports_background_blur 1
  lab_rp ro.os.recent.blur 1
  lab_rp ro.tran_display_unionrender.support 1
  lab_rp ro.tran.effectengine.dynamicblur.support 1
  lab_rp ro.os_xos16_blur_v2_support 1
  lab_rp ro.sf.blurs_are_expensive 1
  lab_rp persist.sys.sf.disable_blurs 0
  lab_rp persist.sys.disable_blur 0
  lab_rp persist.sysui.disableBlur 0
  lab_rp persist.sysui.disable_blur 0
}

lab_lighting() {
  lab_rp persist.tr_lighting.controlcenter.feature.support 1
  lab_rp persist.tr_lighting.feature.support 1
  lab_rp ro.tr_lighting.controlcenter.feature.support 1
  lab_rp ro.tr_lighting.feature.support 1
}

# g = gaussian / folder level (2 or 3)
lab_dock() {
  g="$1"
  [ -n "$g" ] || g=3
  lab_rp ro.transsion_launcher_gaussian_blur_support "$g"
  lab_rp tr_launcher.gaussianblur.support "$g"
  lab_rp tr_launcher.blurrecent.support 1
  lab_rp tr_launcher.folderblur.support "$g"
  lab_rp ro.transsion_launcher_folder_blur_support "$g"
  lab_rp persist.sys.transsion_launcher_gaussian_blur_enable 1
}

lab_dock15() {
  lab_rp ro.transsion_launcher_gaussian_blur_support 2
  lab_rp tr_launcher.gaussianblur.support 2
  lab_rp ro.tran.effectengine.dynamicblur.support 1
  lab_rp persist.sys.transsion_launcher_gaussian_blur_enable 1
}

lab_settings() {
  g="$1"
  [ -n "$g" ] || g=3
  lab_set global disable_window_blurs 0
  lab_set system disable_window_blurs 0
  lab_set global transsion_launcher_gaussian_blur_support "$g"
  lab_set system transsion_launcher_gaussian_blur_support "$g"
  lab_set global transsion_launcher_gaussian_support "$g"
  lab_set system transsion_launcher_gaussian_support "$g"
  lab_set global transsion_launcher_gaussian_blur_enable 1
  lab_set system transsion_launcher_gaussian_blur_enable 1
  lab_set global transsion_launcher_blur_radius 80
  lab_set system transsion_launcher_blur_radius 80
  lab_set global transsion_launcher_folder_blur_support "$g"
  lab_set system transsion_launcher_folder_blur_support "$g"
  lab_set global transsion_launcher_folder_blur_enable 1
  lab_set system transsion_launcher_folder_blur_enable 1
  lab_set global transsion_launcher_blurrecent_support 1
  lab_set system transsion_launcher_blurrecent_support 1
  wm disable-blur 0 >/dev/null 2>&1
  cmd window disable-blur 0 >/dev/null 2>&1
}

lab_device_config() {
  device_config put systemui notification_shade_blur true >/dev/null 2>&1
  device_config put systemui enable_blur_on_windows true >/dev/null 2>&1
  device_config put systemui shade_blur_radius 80 >/dev/null 2>&1
}

lab_write_system_prop() {
  n="$1"
  dest="$MODDIR/system.prop"
  {
    echo "# combo $n - rewritten each boot"
    case "$n" in
      1)
        echo "ro.tr_animation.platform_level=3"
        echo "ro.tr_display.liquidglass.support=1"
        echo "ro.surface_flinger.supports_background_blur=1"
        echo "ro.os.recent.blur=1"
        echo "ro.tran_display_unionrender.support=1"
        echo "ro.tran.effectengine.dynamicblur.support=1"
        echo "ro.os_xos16_blur_v2_support=1"
        echo "ro.sf.blurs_are_expensive=1"
        echo "persist.sys.sf.disable_blurs=0"
        ;;
      2)
        echo "ro.transsion_launcher_gaussian_blur_support=2"
        echo "tr_launcher.gaussianblur.support=2"
        echo "ro.tran.effectengine.dynamicblur.support=1"
        echo "persist.sys.transsion_launcher_gaussian_blur_enable=1"
        ;;
      3)
        echo "ro.transsion_launcher_gaussian_blur_support=3"
        echo "tr_launcher.gaussianblur.support=3"
        echo "tr_launcher.blurrecent.support=1"
        echo "tr_launcher.folderblur.support=3"
        echo "ro.transsion_launcher_folder_blur_support=3"
        echo "persist.sys.transsion_launcher_gaussian_blur_enable=1"
        ;;
      6)
        echo "ro.tr_animation.platform_level=3"
        echo "ro.tr_display.liquidglass.support=1"
        echo "ro.surface_flinger.supports_background_blur=1"
        echo "ro.os.recent.blur=1"
        echo "ro.tran_display_unionrender.support=1"
        echo "ro.tran.effectengine.dynamicblur.support=1"
        echo "ro.os_xos16_blur_v2_support=1"
        echo "ro.sf.blurs_are_expensive=1"
        echo "persist.sys.sf.disable_blurs=0"
        echo "ro.transsion_launcher_gaussian_blur_support=2"
        echo "tr_launcher.gaussianblur.support=2"
        echo "tr_launcher.blurrecent.support=1"
        echo "tr_launcher.folderblur.support=2"
        echo "ro.transsion_launcher_folder_blur_support=2"
        echo "persist.sys.transsion_launcher_gaussian_blur_enable=1"
        echo "persist.tr_lighting.controlcenter.feature.support=1"
        echo "persist.tr_lighting.feature.support=1"
        echo "ro.tr_lighting.controlcenter.feature.support=1"
        echo "ro.tr_lighting.feature.support=1"
        ;;
      *)
        echo "ro.tr_animation.platform_level=3"
        echo "ro.tr_display.liquidglass.support=1"
        echo "ro.surface_flinger.supports_background_blur=1"
        echo "ro.os.recent.blur=1"
        echo "ro.tran_display_unionrender.support=1"
        echo "ro.tran.effectengine.dynamicblur.support=1"
        echo "ro.os_xos16_blur_v2_support=1"
        echo "ro.sf.blurs_are_expensive=1"
        echo "persist.sys.sf.disable_blurs=0"
        echo "ro.transsion_launcher_gaussian_blur_support=3"
        echo "tr_launcher.gaussianblur.support=3"
        echo "tr_launcher.blurrecent.support=1"
        echo "tr_launcher.folderblur.support=3"
        echo "ro.transsion_launcher_folder_blur_support=3"
        echo "persist.sys.transsion_launcher_gaussian_blur_enable=1"
        echo "persist.tr_lighting.controlcenter.feature.support=1"
        echo "persist.tr_lighting.feature.support=1"
        echo "ro.tr_lighting.controlcenter.feature.support=1"
        echo "ro.tr_lighting.feature.support=1"
        ;;
    esac
  } > "$dest"
}

lab_launcher_vconfig() {
  g="$1"
  [ -n "$g" ] || g=3
  live=""
  for p in \
    /tr_product/etc/vconfig/com.transsion.launcher3/build.prop \
    /system/tr_product/etc/vconfig/com.transsion.launcher3/build.prop
  do
    [ -f "$p" ] && { live="$p"; break; }
  done
  [ -n "$live" ] || { lab_log "no launcher3 vconfig"; return 1; }
  staged="$MODDIR/vconfig/com.transsion.launcher3/build.prop"
  mkdir -p "$(dirname "$staged")"
  if [ ! -s "$staged" ]; then
    cat "$live" > "$staged"
  fi
  lab_upsert "$staged" "ro.os.recent.blur" 1
  lab_upsert "$staged" "ro.transsion_launcher_gaussian_blur_support" "$g"
  lab_upsert "$staged" "tr_launcher.gaussianblur.support" "$g"
  lab_upsert "$staged" "tr_launcher.blurrecent.support" 1
  lab_upsert "$staged" "tr_launcher.folderblur.support" "$g"
  lab_upsert "$staged" "ro.transsion_launcher_folder_blur_support" "$g"
  lab_upsert "$staged" "ro.transsion_async_animation_support" 1
  lab_upsert "$staged" "ro.tran_display_unionrender.support" 1
  lab_upsert "$staged" "ro.tr_animation.platform_level" 3
  lab_bind "$staged" "$live"
  lab_bind "$staged" /system/tr_product/etc/vconfig/com.transsion.launcher3/build.prop
  lab_log "bound launcher3 vconfig gaussian=$g"
}

lab_apply_early() {
  n=$(lab_combo)
  lab_write_system_prop "$n"
  lab_log "=== early combo $n ==="
  case "$n" in
    1) lab_shade ;;
    2) lab_dock15 ;;
    3) lab_dock 3 ;;
    4) lab_shade; lab_dock 3 ;;
    5) lab_shade; lab_lighting; lab_dock 3; lab_launcher_vconfig 3 ;;
    6) lab_shade; lab_lighting; lab_dock 2; lab_launcher_vconfig 2 ;;
  esac
  lab_log "early done platform=$(getprop ro.tr_animation.platform_level) gauss=$(getprop tr_launcher.gaussianblur.support) folder=$(getprop tr_launcher.folderblur.support)"
}

lab_apply_late() {
  n=$(lab_combo)
  lab_log "=== late combo $n ==="
  case "$n" in
    1) lab_shade ;;
    2) lab_dock15; lab_settings 2 ;;
    3) lab_dock 3; lab_settings 3 ;;
    4) lab_shade; lab_dock 3; lab_settings 3 ;;
    5)
      lab_shade; lab_lighting; lab_dock 3; lab_settings 3
      lab_device_config
      lab_launcher_vconfig 3
      am force-stop com.transsion.launcher3 >/dev/null 2>&1
      ;;
    6)
      lab_shade; lab_lighting; lab_dock 2; lab_settings 2
      lab_device_config
      lab_launcher_vconfig 2
      am force-stop com.transsion.launcher3 >/dev/null 2>&1
      ;;
  esac
  lab_log "late done enable=$(settings get system transsion_launcher_gaussian_blur_enable) gauss=$(getprop tr_launcher.gaussianblur.support)"
}
