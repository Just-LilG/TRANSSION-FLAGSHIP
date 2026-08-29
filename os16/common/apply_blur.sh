#!/system/bin/sh
# Blur on = write flagship glass. Blur off = drop this module's blur
# overlays and Magisk keys. Do not write blur props.

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

os16_rp_delete() {
  k="$1"
  if [ -x /data/adb/magisk/resetprop ]; then
    /data/adb/magisk/resetprop --delete "$k" >/dev/null 2>&1
  fi
  if command -v resetprop >/dev/null 2>&1; then
    resetprop --delete "$k" >/dev/null 2>&1
  fi
  if [ -x /data/adb/ksud ]; then
    /data/adb/ksud resetprop --delete "$k" >/dev/null 2>&1
  fi
}

os16_read_stock_prop() {
  k="$1"
  for f in /tr_product/etc/build.prop /tr_product/build.prop \
      /system/tr_product/etc/build.prop /system/tr_product/build.prop; do
    [ -f "$f" ] || continue
    line=$(grep -m1 "^${k}=" "$f" 2>/dev/null)
    if [ -n "$line" ]; then
      echo "${line#*=}"
      return 0
    fi
  done
  return 1
}

os16_strip_dynamicbar_systemprop() {
  sp="$MODDIR/system.prop"
  [ -f "$sp" ] || return 0
  for k in \
    ro.tr_dynamicbar.support \
    ro.os_dynamicbar_ai_translation_support \
    ro.os_dynamic_bar_resident_plane_support \
    ro.os.tran_hide_status_bar_for_land_recent \
    ro.tran_hios_dynamic_bar_support
  do
    sed -i "/^${k}=/d" "$sp" 2>/dev/null
  done
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
  content update --uri content://settings/"$ns" \
    --bind value:s:"$v" \
    --where "name='$k'" >/dev/null 2>&1
}

os16_blur_vals() {
  anim=$(os16_cfg_bool anim_os16 true)
  on=$(os16_cfg_bool blur_os16 true)

  SKIP_BLUR=0
  SOLID_SHADE=0
  DOCK_BLUR=0
  GLASS=0
  BLVL=0
  EN=0
  RAD=0
  B01=0
  DYNBLUR=0
  BLURV2=0
  SFDIS=0
  DIS=0
  EXP=0
  LAUNCHER_ASYNC=0
  BLUR_RECENT=0
  UNION=0
  LIGHT_CC=0
  LIGHT_FEAT=0
  ALVL=0
  PERF_LVL=0
  MOTION_PLAT=0
  A01=0

  if [ "$anim" = "true" ] || [ "$anim" = "1" ]; then
    A01=1
    PERF_LVL=3
    ALVL=3
    MOTION_PLAT=3
    LAUNCHER_ASYNC=1
  fi

  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    SOLID_SHADE=0
    DOCK_BLUR=1
    GLASS=1
    BLVL=3
    BLUR_RECENT=1
    EN=1
    RAD=80
    B01=1
    SFDIS=0
    DIS=0
    DYNBLUR=1
    BLURV2=1
    EXP=1
    LIGHT_CC=1
    LIGHT_FEAT=1
    [ "$A01" = "1" ] && UNION=1
  else
    SKIP_BLUR=1
  fi

  SHADE_PLAT=$ALVL
  SYSUI_PLAT=$ALVL
  BLUR_ON=$on
  BLUR_LVL=3
  ANIM_ON=$anim
}

os16_drop_module_blur() {
  os16_unbind_tr_product_blur_buildprop
  os16_unbind_vconfig_pkg com.android.systemui
  os16_unbind_vconfig_pkg com.transsion.systemui
  os16_strip_blur_systemprop
  for k in \
    ro.tr_animation.platform_level \
    ro.tr_display.liquidglass.support \
    ro.surface_flinger.supports_background_blur \
    ro.os.recent.blur \
    ro.transsion_launcher_gaussian_blur_support \
    tr_launcher.gaussianblur.support \
    tr_launcher.blurrecent.support \
    tr_launcher.folderblur.support \
    ro.transsion_launcher_folder_blur_support \
    persist.sys.transsion_launcher_gaussian_blur_enable \
    ro.tran.effectengine.dynamicblur.support \
    ro.os_xos16_blur_v2_support \
    persist.sys.sf.disable_blurs \
    persist.sys.disable_blur \
    persist.sysui.disableBlur \
    persist.sysui.disable_blur \
    ro.sf.blurs_are_expensive \
    persist.tr_lighting.controlcenter.feature.support \
    persist.tr_lighting.feature.support \
    ro.tr_lighting.controlcenter.feature.support \
    ro.tr_lighting.feature.support \
    ro.tran_display_unionrender.support
  do
    os16_rp_delete "$k"
  done
}

# Parallel = perf / launch / unlock / recent / async. platform_level is blur.
os16_apply_anim_props() {
  os16_blur_vals
  os16_rp_overwrite ro.tr_perf.launch_start_exit.model "$PERF_LVL"
  os16_rp_overwrite ro.tr_perf.power_keyguard_animation.model "$PERF_LVL"
  os16_rp_overwrite ro.tr_perf.recent_animation.model "$PERF_LVL"
  os16_rp_overwrite ro.tr_perf.unlock_mode.model "$PERF_LVL"
  os16_rp ro.tr_livewallpaper.dreamanimation.support "$A01"
  os16_rp ro.tr_multiwindow.anim_arc.support "$A01"
  os16_rp ro.transsion_async_animation_support "$LAUNCHER_ASYNC"
  os16_rp ro.transsion_unlock_mode_support "$PERF_LVL"
  os16_rp ro.transsion_launch_start_exit_support "$PERF_LVL"
  os16_rp ro.transsion_power_keyguard_animation_support "$PERF_LVL"
  os16_rp ro.transsion.recent_animation.model "$PERF_LVL"
  if [ "$SKIP_BLUR" = "1" ] || [ "$A01" != "1" ]; then
    os16_rp_delete ro.tr_animation.platform_level
  else
    os16_rp_overwrite ro.tr_animation.platform_level "$ALVL"
  fi
}

os16_apply_blur_props() {
  os16_apply_anim_props
  [ "$SKIP_BLUR" = "1" ] && return 0
  os16_rp_overwrite ro.tran_display_unionrender.support "$UNION"
  os16_rp_overwrite ro.tr_display.liquidglass.support "$B01"
  os16_rp_overwrite ro.surface_flinger.supports_background_blur "$B01"
  os16_rp_overwrite ro.os.recent.blur "$B01"
  os16_rp_overwrite ro.transsion_launcher_gaussian_blur_support "$BLVL"
  os16_rp_overwrite tr_launcher.gaussianblur.support "$BLVL"
  os16_rp_overwrite tr_launcher.blurrecent.support "$BLUR_RECENT"
  os16_rp_overwrite tr_launcher.folderblur.support "$BLVL"
  os16_rp_overwrite ro.transsion_launcher_folder_blur_support "$BLVL"
  os16_rp persist.sys.transsion_launcher_gaussian_blur_enable "$EN"
  os16_rp_overwrite ro.tran.effectengine.dynamicblur.support "$DYNBLUR"
  os16_rp_overwrite ro.os_xos16_blur_v2_support "$BLURV2"
  os16_rp persist.sys.sf.disable_blurs "$SFDIS"
  os16_rp persist.sys.disable_blur "$DIS"
  os16_rp persist.sysui.disableBlur "$SFDIS"
  os16_rp persist.sysui.disable_blur "$SFDIS"
  os16_rp ro.sf.blurs_are_expensive "$EXP"
  os16_rp persist.tr_lighting.controlcenter.feature.support "$LIGHT_CC"
  os16_rp persist.tr_lighting.feature.support "$LIGHT_FEAT"
  os16_rp_overwrite ro.tr_lighting.controlcenter.feature.support "$LIGHT_CC"
  os16_rp_overwrite ro.tr_lighting.feature.support "$LIGHT_FEAT"
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

os16_unbind_vconfig_pkg() {
  pkg="$1"
  NS=$(os16_vconfig_nsenter)
  for dest in \
    /tr_product/etc/vconfig/$pkg/build.prop \
    /system/tr_product/etc/vconfig/$pkg/build.prop \
    /product/etc/vconfig/$pkg/build.prop \
    /system/product/etc/vconfig/$pkg/build.prop
  do
    [ -n "$NS" ] && $NS umount -l "$dest" 2>/dev/null
    umount -l "$dest" 2>/dev/null
  done
  rm -rf "$MODDIR/system/tr_product/etc/vconfig/$pkg"
  rm -f "$MODDIR/vconfig/$pkg/build.prop"
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
      cp -f "$staged" "${staged}.stock"
    else
      : > "$staged"
    fi
  fi
  echo "$staged"
}

os16_restore_vconfig_key_from_stock() {
  f="$1"
  k="$2"
  stock="${f}.stock"
  if [ -f "$stock" ] && grep -q "^${k}=" "$stock" 2>/dev/null; then
    val=$(grep -m1 "^${k}=" "$stock" | cut -d= -f2-)
    os16_vconfig_upsert "$f" "$k" "$val"
  else
    sed -i "/^${k}=/d" "$f" 2>/dev/null
  fi
}

os16_tr_product_blur_stock() {
  echo "$MODDIR/tr_product/etc/build.prop.stock"
}

os16_seed_tr_product_buildprop() {
  stock=$(os16_tr_product_blur_stock)
  [ -s "$stock" ] && return 0
  mkdir -p "$(dirname "$stock")"
  src=""
  for p in /tr_product/etc/build.prop /system/tr_product/etc/build.prop; do
    [ -f "$p" ] || continue
    src="$p"
    break
  done
  [ -n "$src" ] || return 1
  cp -f "$src" "$stock"
}

os16_apply_tr_product_blur_buildprop() {
  os16_blur_vals
  [ "$SKIP_BLUR" = "1" ] && { os16_unbind_tr_product_blur_buildprop; return 0; }
  stock=$(os16_tr_product_blur_stock)
  os16_seed_tr_product_buildprop || return 0
  staged="$MODDIR/tr_product/etc/build.prop"
  mkdir -p "$(dirname "$staged")"
  cp -f "$stock" "$staged"
  os16_vconfig_upsert "$staged" "ro.tr_display.liquidglass.support" "$B01"
  os16_vconfig_upsert "$staged" "ro.surface_flinger.supports_background_blur" "$B01"
  os16_vconfig_upsert "$staged" "ro.os.recent.blur" "$B01"
  os16_vconfig_upsert "$staged" "ro.transsion_launcher_gaussian_blur_support" "$BLVL"
  os16_vconfig_upsert "$staged" "tr_launcher.gaussianblur.support" "$BLVL"
  os16_vconfig_upsert "$staged" "tr_launcher.blurrecent.support" "$BLUR_RECENT"
  os16_vconfig_upsert "$staged" "tr_launcher.folderblur.support" "$BLVL"
  os16_vconfig_upsert "$staged" "ro.transsion_launcher_folder_blur_support" "$BLVL"
  os16_vconfig_upsert "$staged" "ro.tran.effectengine.dynamicblur.support" "$DYNBLUR"
  os16_vconfig_upsert "$staged" "ro.os_xos16_blur_v2_support" "$BLURV2"
  os16_vconfig_upsert "$staged" "ro.sf.blurs_are_expensive" "$EXP"
  os16_vconfig_upsert "$staged" "ro.transsion_async_animation_support" "$LAUNCHER_ASYNC"
  os16_vconfig_upsert "$staged" "ro.tran_display_unionrender.support" "$UNION"
  os16_vconfig_upsert "$staged" "ro.tr_lighting.controlcenter.feature.support" "$LIGHT_CC"
  os16_vconfig_upsert "$staged" "ro.tr_lighting.feature.support" "$LIGHT_FEAT"
  os16_vconfig_upsert "$staged" "ro.tr_animation.platform_level" "$SHADE_PLAT"
  mkdir -p "$MODDIR/system/tr_product/etc"
  cp -f "$staged" "$MODDIR/system/tr_product/etc/build.prop"
  for dest in \
    /tr_product/etc/build.prop \
    /system/tr_product/etc/build.prop
  do
    os16_bind_file "$staged" "$dest"
  done
}

os16_unbind_tr_product_blur_buildprop() {
  NS=$(os16_vconfig_nsenter)
  for dest in \
    /tr_product/etc/build.prop \
    /system/tr_product/etc/build.prop
  do
    [ -n "$NS" ] && $NS umount -l "$dest" 2>/dev/null
    umount -l "$dest" 2>/dev/null
  done
}

os16_cfg_tf() {
  k="$1"; d="$2"
  v=$(os16_cfg_bool "$k" "$d")
  if [ "$v" = "false" ] || [ "$v" = "0" ]; then
    echo false
  else
    echo true
  fi
}

os16_apply_aod_vconfig() {
  aod=$(os16_cfg_01 aod_os16 true)
  staged=$(os16_seed_vconfig_pkg com.transsion.aod)
  os16_vconfig_upsert "$staged" "tr_aod.always.show.feature.support" "$aod"
  os16_vconfig_upsert "$staged" "tr_aod.horizontal.display.feature.support" "$aod"
  os16_bind_vconfig_pkg "$staged" com.transsion.aod
}

os16_motion_vconfig_keys() {
  f="$1"
  plat="$2"
  [ -n "$plat" ] || return 0
  [ "$plat" != "0" ] || return 0
  os16_blur_vals
  if [ "$SKIP_BLUR" != "1" ]; then
    os16_vconfig_upsert "$f" "ro.tr_animation.platform_level" "$plat"
  else
    os16_restore_vconfig_key_from_stock "$f" "ro.tr_animation.platform_level"
  fi
  os16_vconfig_upsert "$f" "ro.tr_perf.launch_start_exit.model" "$plat"
  os16_vconfig_upsert "$f" "ro.tr_perf.power_keyguard_animation.model" "$plat"
  os16_vconfig_upsert "$f" "ro.tr_perf.recent_animation.model" "$plat"
  os16_vconfig_upsert "$f" "ro.tr_perf.unlock_mode.model" "$plat"
  os16_vconfig_upsert "$f" "ro.transsion_launch_start_exit_support" "$plat"
  os16_vconfig_upsert "$f" "ro.transsion_power_keyguard_animation_support" "$plat"
  os16_vconfig_upsert "$f" "ro.transsion.recent_animation.model" "$plat"
  os16_vconfig_upsert "$f" "ro.transsion_unlock_mode_support" "$plat"
}

os16_apply_motion_pkg_vconfig() {
  os16_blur_vals
  [ "$MOTION_PLAT" = "3" ] || return 0
  for pkg in com.transsion.wm com.android.wm com.android.shell com.transsion.perf; do
    staged=$(os16_seed_vconfig_pkg "$pkg")
    stock="${staged}.stock"
    [ -s "$stock" ] || continue
    os16_motion_vconfig_keys "$staged" "$MOTION_PLAT"
    os16_bind_vconfig_pkg "$staged" "$pkg"
  done
}

os16_apply_launcher_vconfig_all() {
  os16_blur_vals
  if [ "$SKIP_BLUR" = "1" ]; then
    staged=$(os16_seed_vconfig_pkg com.transsion.launcher3)
    stock="${staged}.stock"
    if [ -f "$stock" ]; then
      cp -f "$stock" "$staged"
    fi
    if [ "$MOTION_PLAT" = "3" ]; then
      os16_motion_vconfig_keys "$staged" "$MOTION_PLAT"
      os16_vconfig_upsert "$staged" "ro.transsion_async_animation_support" "$LAUNCHER_ASYNC"
      os16_bind_vconfig_pkg "$staged" com.transsion.launcher3
    else
      os16_unbind_vconfig_pkg com.transsion.launcher3
    fi
    os16_unbind_vconfig_pkg com.transsion.hilauncher
    os16_unbind_vconfig_pkg com.transsion.XOSLauncher
    os16_unbind_vconfig_pkg com.transsion.launcher
    return 0
  fi
  staged=$(os16_seed_vconfig_pkg com.transsion.launcher3)
  os16_vconfig_upsert "$staged" "ro.os.recent.blur" "1"
  os16_vconfig_upsert "$staged" "ro.transsion_launcher_gaussian_blur_support" "$BLVL"
  os16_vconfig_upsert "$staged" "tr_launcher.gaussianblur.support" "$BLVL"
  os16_vconfig_upsert "$staged" "tr_launcher.blurrecent.support" "$BLUR_RECENT"
  os16_vconfig_upsert "$staged" "tr_launcher.folderblur.support" "$BLVL"
  os16_vconfig_upsert "$staged" "ro.transsion_launcher_folder_blur_support" "$BLVL"
  os16_vconfig_upsert "$staged" "ro.transsion_async_animation_support" "$LAUNCHER_ASYNC"
  os16_vconfig_upsert "$staged" "ro.tran_display_unionrender.support" "$UNION"
  os16_motion_vconfig_keys "$staged" "$MOTION_PLAT"
  bar=$(os16_cfg_01 dynamicbar_os16 false)
  if [ "$bar" = "1" ]; then
    os16_vconfig_upsert "$staged" "ro.os.tran_hide_status_bar_for_land_recent" "1"
  else
    os16_restore_vconfig_key_from_stock "$staged" "ro.os.tran_hide_status_bar_for_land_recent"
  fi
  os16_bind_vconfig_pkg "$staged" com.transsion.launcher3
  os16_unbind_vconfig_pkg com.transsion.hilauncher
  os16_unbind_vconfig_pkg com.transsion.XOSLauncher
  os16_unbind_vconfig_pkg com.transsion.launcher
}

os16_apply_systemui_vconfig() {
  os16_blur_vals
  if [ "$SKIP_BLUR" = "1" ]; then
    os16_unbind_vconfig_pkg com.android.systemui
    os16_unbind_vconfig_pkg com.transsion.systemui
    return 0
  fi
  staged=$(os16_seed_vconfig_pkg com.android.systemui)
  stock="${staged}.stock"
  if [ "$SOLID_SHADE" = "1" ]; then
    os16_vconfig_upsert "$staged" "ro.tr_animation.platform_level" "$SYSUI_PLAT"
    os16_vconfig_upsert "$staged" "ro.tr_lighting.controlcenter.feature.support" "$LIGHT_CC"
    os16_vconfig_upsert "$staged" "ro.tr_lighting.feature.support" "$LIGHT_FEAT"
    os16_vconfig_upsert "$staged" "ro.tr_display.liquidglass.support" "0"
    os16_vconfig_upsert "$staged" "ro.tran_display_unionrender.support" "0"
  elif [ -f "$stock" ]; then
    for k in \
      ro.tr_animation.platform_level \
      ro.tr_lighting.controlcenter.feature.support \
      ro.tr_lighting.feature.support \
      ro.tr_display.liquidglass.support \
      ro.tran_display_unionrender.support
    do
      os16_restore_vconfig_key_from_stock "$staged" "$k"
    done
  fi
  if [ -f "$stock" ]; then
    keys=$(grep -iE 'blur|glass|glow|lighting|transparen|liquid|shade' "$stock" 2>/dev/null)
    if [ -n "$keys" ]; then
      printf '%s\n' "$keys" | while IFS= read -r line; do
        k="${line%%=*}"
        [ -n "$k" ] || continue
        case "$k" in
          ro.tr_animation.platform_level|ro.tr_lighting.controlcenter.feature.support|ro.tr_lighting.feature.support|ro.tr_display.liquidglass.support|ro.tran_display_unionrender.support)
            continue
            ;;
        esac
        if [ "$SOLID_SHADE" = "1" ]; then
          os16_vconfig_upsert "$staged" "$k" "0"
        else
          val="${line#*=}"
          os16_vconfig_upsert "$staged" "$k" "$val"
        fi
      done
    fi
  fi
  os16_bind_vconfig_pkg "$staged" com.android.systemui
  os16_bind_vconfig_pkg "$staged" com.transsion.systemui
}

os16_strip_blur_systemprop() {
  sp="$MODDIR/system.prop"
  [ -f "$sp" ] || return 0
  for k in \
    ro.tr_animation.platform_level \
    ro.tran_display_unionrender.support \
    ro.tr_display.liquidglass.support \
    ro.surface_flinger.supports_background_blur \
    ro.os.recent.blur \
    ro.transsion_launcher_gaussian_blur_support \
    tr_launcher.gaussianblur.support \
    tr_launcher.blurrecent.support \
    tr_launcher.folderblur.support \
    ro.transsion_launcher_folder_blur_support \
    persist.sys.transsion_launcher_gaussian_blur_enable \
    ro.tran.effectengine.dynamicblur.support \
    ro.os_xos16_blur_v2_support \
    persist.sys.sf.disable_blurs \
    persist.sys.disable_blur \
    persist.sysui.disableBlur \
    persist.sysui.disable_blur \
    ro.sf.blurs_are_expensive \
    persist.tr_lighting.controlcenter.feature.support \
    persist.tr_lighting.feature.support \
    ro.tr_lighting.controlcenter.feature.support \
    ro.tr_lighting.feature.support
  do
    sed -i "/^${k}=/d" "$sp" 2>/dev/null
  done
}

os16_apply_blur_stack() {
  os16_blur_vals
  if [ "$SKIP_BLUR" = "1" ]; then
    os16_drop_module_blur
    os16_apply_anim_props
    os16_apply_motion_pkg_vconfig
    os16_apply_launcher_vconfig_all
  else
    os16_apply_blur_props
    os16_apply_tr_product_blur_buildprop
    os16_apply_launcher_vconfig_all
    os16_apply_systemui_vconfig
  fi
  os16_apply_dynamicbar_props
}

os16_clear_dynamicbar_props() {
  os16_strip_dynamicbar_systemprop
  for k in \
    ro.tr_dynamicbar.support \
    ro.os_dynamicbar_ai_translation_support \
    ro.os_dynamic_bar_resident_plane_support \
    ro.os.tran_hide_status_bar_for_land_recent \
    ro.tran_hios_dynamic_bar_support
  do
    stock=$(os16_read_stock_prop "$k")
    if [ -n "$stock" ]; then
      os16_rp "$k" "$stock"
    else
      os16_rp_delete "$k"
    fi
  done
  # Do not unbind launcher3 vconfig — blur tier keys live in the same file.
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

os16_apply_videosr_props() {
  v=$(os16_cfg_01 videosr_os16 true)
  os16_rp_overwrite persist.tr_video.ai_super_resolution.support "$v"
  os16_rp_overwrite ro.tr_video.ai_super_resolution.support "$v"
  os16_rp_overwrite tr_video.ai_super_resolution.support "$v"
}

os16_apply_supervol_props() {
  v=$(os16_cfg_tf supervol_os16 true)
  os16_rp_overwrite ro.tr_audio.supervol.feature.support "$v"
  os16_rp_overwrite tr_audio.supervol.feature.support "$v"
}

os16_apply_treasure_props() {
  t=$(os16_cfg_01 treasure_os16 true)
  os16_rp_overwrite ro.tr_ai_treasure_box.feature.support "$t"
  os16_rp_overwrite tr_ai_treasure_box.feature.support "$t"
}

os16_apply_cutepet_props() {
  p=$(os16_cfg_01 cutepet_os16 true)
  # OS 16 GT dump + Flagship 15 alias. For every Trans OS 16 device.
  os16_rp_overwrite ro.tr_cutepet.feature.support "$p"
  os16_rp_overwrite tr_cutepet.feature.support "$p"
  os16_rp_overwrite ro.os_cutepet_support "$p"
}

os16_apply_outdoorboost_props() {
  o=$(os16_cfg_01 outdoorboost_os16 true)
  os16_rp_overwrite ro.tr_outdoorboost.feature.support "$o"
  os16_rp_overwrite tr_outdoorboost.feature.support "$o"
}

os16_apply_gallerylive_props() {
  lv=$(os16_cfg_01 gallerylive_os16 true)
  # GT dump: tr_gallery.live.support=0 (Flagship 15 already shipped this).
  os16_rp_overwrite tr_gallery.live.support "$lv"
  os16_rp_overwrite tr_gallery.live.slow.support "$lv"
  os16_rp_overwrite ro.tr_gallery.live.support "$lv"
  os16_rp_overwrite ro.tr_gallery.live.slow.support "$lv"
}

os16_apply_airtransfer_props() {
  at=$(os16_cfg_01 airtransfer_os16 true)
  # GT dump 1 = on. That is a real GT extra, not a dump-0 off flag.
  os16_rp_overwrite ro.tr_airtransfer.feature.support "$at"
  os16_rp_overwrite tr_airtransfer.feature.support "$at"
}

os16_apply_os16_extras_props() {
  os16_apply_videosr_props
  os16_apply_supervol_props
  os16_apply_treasure_props
  os16_apply_cutepet_props
  os16_apply_outdoorboost_props
  os16_apply_gallerylive_props
  os16_apply_airtransfer_props
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
}

os16_apply_dynamicbar_props() {
  bar=$(os16_cfg_bool dynamicbar_os16 false)
  if [ "$bar" != "true" ] && [ "$bar" != "1" ]; then
    os16_clear_dynamicbar_props
    return 0
  fi
  os16_rp_overwrite ro.tr_dynamicbar.support 1
  os16_rp_overwrite ro.os_dynamicbar_ai_translation_support 1
  os16_rp_overwrite ro.tran_hios_dynamic_bar_support 1
  os16_rp_overwrite ro.os_dynamic_bar_resident_plane_support 1
  os16_rp_overwrite ro.os.tran_hide_status_bar_for_land_recent 1
}

os16_apply_dynamicbar_runtime() {
  for ns in system global secure; do
    settings delete "$ns" os_dynamic_bar_resident_plane >/dev/null 2>&1
    settings delete "$ns" island_always_show_background >/dev/null 2>&1
    settings delete "$ns" tran_dynamic_bar_always_show >/dev/null 2>&1
  done
}

os16_clear_failed_feature_leftovers() {
  dc=$(os16_cfg_01 display_dc true)
  col=$(os16_cfg_01 display_color true)
  hdr=$(os16_cfg_01 display_hdr true)
  rd=$(os16_cfg_01 display_reading false)
  if [ "$dc" = "1" ] || [ "$col" = "1" ] || [ "$hdr" = "1" ] || [ "$rd" = "1" ]; then
    return 0
  fi
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

os16_refresh_systemui_on_apply() {
  am force-stop com.android.systemui >/dev/null 2>&1
}

os16_refresh_launcher_on_apply() {
  am force-stop com.transsion.launcher3 >/dev/null 2>&1
  am force-stop com.transsion.hilauncher >/dev/null 2>&1
  am force-stop com.transsion.XOSLauncher >/dev/null 2>&1
  am force-stop com.transsion.launcher >/dev/null 2>&1
}

os16_restart_systemui() {
  os16_refresh_systemui_on_apply
}

os16_restart_surfaceflinger() {
  :
}

os16_clear_blur_runtime_settings() {
  settings delete global disable_window_blurs >/dev/null 2>&1
  settings delete system disable_window_blurs >/dev/null 2>&1
  settings delete secure accessibility_reduce_transparency >/dev/null 2>&1
  settings delete secure reduce_blur_effects >/dev/null 2>&1
  for ns in system global; do
    settings delete "$ns" reduce_blur_effects >/dev/null 2>&1
    settings delete "$ns" tran_glow_space_enable >/dev/null 2>&1
    settings delete "$ns" tr_glow_space_enable >/dev/null 2>&1
    settings delete "$ns" tran_control_center_blur_enable >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_gaussian_blur_support >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_gaussian_support >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_gaussian_blur_enable >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_blur_radius >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_folder_blur_support >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_folder_blur_enable >/dev/null 2>&1
    settings delete "$ns" transsion_launcher_blurrecent_support >/dev/null 2>&1
  done
}

os16_apply_blur_runtime() {
  os16_blur_vals
  if [ "$SKIP_BLUR" = "1" ]; then
    os16_clear_blur_runtime_settings
    device_config delete systemui notification_shade_blur >/dev/null 2>&1
    device_config delete systemui enable_blur_on_windows >/dev/null 2>&1
    device_config delete systemui shade_blur_radius >/dev/null 2>&1
    return 0
  fi
  os16_settings_put global disable_window_blurs "$DIS"
  os16_settings_put system disable_window_blurs "$DIS"
  if [ "$SOLID_SHADE" = "1" ]; then
    os16_settings_put secure accessibility_reduce_transparency 1
    os16_settings_put secure reduce_blur_effects 1
    os16_settings_put system reduce_blur_effects 1
    os16_settings_put global reduce_blur_effects 1
    os16_settings_put global tran_glow_space_enable 0
    os16_settings_put system tran_glow_space_enable 0
    os16_settings_put global tr_glow_space_enable 0
    os16_settings_put system tr_glow_space_enable 0
    os16_settings_put global tran_control_center_blur_enable 0
    os16_settings_put system tran_control_center_blur_enable 0
  else
    settings delete secure accessibility_reduce_transparency >/dev/null 2>&1
    settings delete secure reduce_blur_effects >/dev/null 2>&1
    for ns in system global; do
      settings delete "$ns" reduce_blur_effects >/dev/null 2>&1
      settings delete "$ns" tran_glow_space_enable >/dev/null 2>&1
      settings delete "$ns" tr_glow_space_enable >/dev/null 2>&1
      settings delete "$ns" tran_control_center_blur_enable >/dev/null 2>&1
    done
  fi
  os16_settings_put global transsion_launcher_gaussian_blur_support "$BLVL"
  os16_settings_put system transsion_launcher_gaussian_blur_support "$BLVL"
  os16_settings_put global transsion_launcher_gaussian_support "$BLVL"
  os16_settings_put system transsion_launcher_gaussian_support "$BLVL"
  if [ "$DOCK_BLUR" = "1" ]; then
    os16_settings_put global transsion_launcher_gaussian_blur_enable "$EN"
    os16_settings_put system transsion_launcher_gaussian_blur_enable "$EN"
    os16_settings_put global transsion_launcher_blur_radius "$RAD"
    os16_settings_put system transsion_launcher_blur_radius "$RAD"
    os16_settings_put global transsion_launcher_folder_blur_support 3
    os16_settings_put system transsion_launcher_folder_blur_support 3
    os16_settings_put global transsion_launcher_folder_blur_enable 1
    os16_settings_put system transsion_launcher_folder_blur_enable 1
    os16_settings_put global transsion_launcher_blurrecent_support 1
    os16_settings_put system transsion_launcher_blurrecent_support 1
  else
    os16_settings_put global transsion_launcher_gaussian_blur_enable 0
    os16_settings_put system transsion_launcher_gaussian_blur_enable 0
    settings delete system transsion_launcher_blur_radius >/dev/null 2>&1
    settings delete global transsion_launcher_blur_radius >/dev/null 2>&1
  fi
  wm disable-blur "$DIS" >/dev/null 2>&1
  cmd window disable-blur "$DIS" >/dev/null 2>&1
  if [ "$GLASS" = "1" ]; then
    device_config put systemui notification_shade_blur true >/dev/null 2>&1
    device_config put systemui enable_blur_on_windows true >/dev/null 2>&1
    device_config put systemui shade_blur_radius 80 >/dev/null 2>&1
  else
    device_config put systemui notification_shade_blur false >/dev/null 2>&1
    device_config put systemui enable_blur_on_windows false >/dev/null 2>&1
    device_config put systemui shade_blur_radius 0 >/dev/null 2>&1
  fi
}

if [ "${0##*/}" = "apply_blur.sh" ]; then
  mode="${1:-all}"
  case "$mode" in
    props) os16_apply_blur_stack; os16_apply_aod_props; os16_apply_os16_extras_props ;;
    runtime)
      os16_apply_blur_runtime
      os16_apply_aod_settings
      os16_apply_dynamicbar_runtime
      os16_refresh_systemui_on_apply
      ;;
    *)
      os16_apply_blur_stack
      os16_apply_aod_props
      os16_apply_os16_extras_props
      os16_clear_failed_feature_leftovers
      os16_apply_aod_settings
      os16_apply_dynamicbar_runtime
      if [ -f "$MODDIR/apply_unlock.sh" ]; then
        . "$MODDIR/apply_unlock.sh"
        os16_apply_unlock
      fi
      os16_apply_blur_runtime
      os16_refresh_systemui_on_apply
      os16_refresh_launcher_on_apply
      ;;
  esac
fi
