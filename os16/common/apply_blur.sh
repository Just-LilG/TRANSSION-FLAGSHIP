#!/system/bin/sh
# Blur tiers (X6886 / Trans OS 16):
#   1 = Smart-series — no glass anywhere (solid lock clock + shade), Parallel platform 3
#   2 = device default — dock/recents blur only, shade solid (Disable-blur partial)
#   3 = flagship — glass everywhere (unionrender + compositor on)

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

  # Safe defaults = level 1 Smart solid.
  SOLID_SHADE=1
  DOCK_BLUR=0
  GLASS=0
  BLVL=0
  EN=0
  RAD=0
  B01=0
  DYNBLUR=0
  BLURV2=0
  SFDIS=1
  DIS=1
  EXP=0
  LAUNCHER_ASYNC=0
  BLUR_RECENT=0

  if [ "$anim" = "true" ] || [ "$anim" = "1" ]; then
    A01=1
    ALVL=3
  else
    A01=0
    ALVL=0
  fi
  UNION=0

  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    case "$lvl" in
      1)
        # Smart 20 style — solid everywhere, no dock blur, Parallel stays.
        SOLID_SHADE=1
        DOCK_BLUR=0
        GLASS=0
        BLVL=0
        BLUR_RECENT=0
        ;;
      2)
        # G99 stock partial — gaussian 2 on dock/recents, shade stays solid.
        SOLID_SHADE=1
        DOCK_BLUR=1
        GLASS=0
        BLVL=2
        BLUR_RECENT=1
        EN=1
        RAD=25
        LAUNCHER_ASYNC=1
        ;;
      3)
        # Full flagship glass — shade + dock + unionrender.
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
        LAUNCHER_ASYNC=1
        [ "$anim" = "true" ] || [ "$anim" = "1" ] && UNION=1
        ;;
    esac
  else
    # Blur off — same as level 1 Smart solid.
    SOLID_SHADE=1
    DOCK_BLUR=0
    GLASS=0
    BLVL=0
    BLUR_RECENT=0
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
  # TranOS Anim Only lv3 keeps platform 3 but async 0 at solid tier.
  os16_rp ro.transsion_async_animation_support "$LAUNCHER_ASYNC"
  os16_rp ro.transsion_unlock_mode_support "$ALVL"
  os16_rp ro.transsion_launch_start_exit_support "$ALVL"
  os16_rp ro.transsion_power_keyguard_animation_support "$ALVL"
  os16_rp ro.transsion.recent_animation.model "$ALVL"
  os16_rp_overwrite ro.tran_display_unionrender.support "$UNION"
  os16_rp_overwrite ro.tr_display.liquidglass.support "$B01"
  os16_rp_overwrite ro.surface_flinger.supports_background_blur "$B01"
  os16_rp_overwrite ro.os.recent.blur "$B01"
  os16_rp_overwrite ro.transsion_launcher_gaussian_blur_support "$BLVL"
  os16_rp_overwrite tr_launcher.gaussianblur.support "$BLVL"
  os16_rp_overwrite ro.tran.effectengine.dynamicblur.support "$DYNBLUR"
  os16_rp_overwrite ro.os_xos16_blur_v2_support "$BLURV2"
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
  os16_vconfig_upsert "$staged" "ro.tran.effectengine.dynamicblur.support" "$DYNBLUR"
  os16_vconfig_upsert "$staged" "ro.os_xos16_blur_v2_support" "$BLURV2"
  os16_vconfig_upsert "$staged" "ro.sf.blurs_are_expensive" "$EXP"
  os16_vconfig_upsert "$staged" "ro.transsion_async_animation_support" "$LAUNCHER_ASYNC"
  os16_vconfig_upsert "$staged" "ro.tran_display_unionrender.support" "$UNION"
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
  # GT X6858 dump: /tr_product/etc/vconfig/com.transsion.aod/build.prop
  #   tr_aod.always.show.feature.support=1
  #   tr_aod.horizontal.display.feature.support=1
  # That is Always Show AOD. Magisk system.prop never reaches this file.
  os16_vconfig_upsert "$staged" "tr_aod.always.show.feature.support" "$aod"
  os16_vconfig_upsert "$staged" "tr_aod.horizontal.display.feature.support" "$aod"
  os16_bind_vconfig_pkg "$staged" com.transsion.aod
}

os16_apply_launcher_vconfig_all() {
  os16_blur_vals
  staged=$(os16_seed_vconfig_pkg com.transsion.launcher3)
  if [ "$GLASS" = "1" ]; then
    os16_vconfig_upsert "$staged" "ro.os.recent.blur" "1"
    os16_vconfig_upsert "$staged" "ro.transsion_launcher_gaussian_blur_support" "$BLVL"
    os16_vconfig_upsert "$staged" "tr_launcher.gaussianblur.support" "$BLVL"
    os16_vconfig_upsert "$staged" "ro.transsion_async_animation_support" "$LAUNCHER_ASYNC"
    os16_vconfig_upsert "$staged" "ro.tran_display_unionrender.support" "$UNION"
  else
    # Level 2 partial = dock blur only; shade solid (Disable-blur vconfig path).
    os16_vconfig_upsert "$staged" "tr_launcher.gaussianblur.support" "$BLVL"
    os16_vconfig_upsert "$staged" "tr_launcher.blurrecent.support" "$BLUR_RECENT"
    os16_vconfig_upsert "$staged" "ro.os.tran_recent_dismiss_single_task_spring_support" "1"
    os16_vconfig_upsert "$staged" "ro.os.tran_recent_drag_down_single_task_spring_support" "1"
    os16_vconfig_upsert "$staged" "tr_launcher.hidefreezer.support" "1"
    os16_vconfig_upsert "$staged" "ro.os.recent.blur" "0"
    os16_vconfig_upsert "$staged" "ro.transsion_launcher_gaussian_blur_support" "$BLVL"
    os16_vconfig_upsert "$staged" "ro.transsion_async_animation_support" "0"
    os16_vconfig_upsert "$staged" "ro.tran_display_unionrender.support" "0"
  fi
  bar=$(os16_cfg_01 dynamicbar_os16 false)
  if [ "$bar" = "1" ]; then
    os16_vconfig_upsert "$staged" "ro.os.tran_hide_status_bar_for_land_recent" "1"
  else
    os16_restore_vconfig_key_from_stock "$staged" "ro.os.tran_hide_status_bar_for_land_recent"
  fi
  os16_bind_vconfig_pkg "$staged" com.transsion.launcher3
}

os16_apply_blur_stack() {
  os16_apply_blur_props
  os16_apply_tr_product_blur_buildprop
  os16_apply_dynamicbar_props
  os16_apply_launcher_vconfig_all
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
    # Off must not write ro.tr_dynamicbar.support=0 — that kills the stock
    # Dynamic Bar this phone already had. Drop module overrides only.
    os16_clear_dynamicbar_props
    return 0
  fi
  os16_rp_overwrite ro.tr_dynamicbar.support 1
  os16_rp_overwrite ro.os_dynamicbar_ai_translation_support 1
  os16_rp_overwrite ro.tran_hios_dynamic_bar_support 1
  # Unhides Settings → Dynamic Bar → Always Show Background.
  os16_rp_overwrite ro.os_dynamic_bar_resident_plane_support 1
  # Landscape-recents status-bar overlay (empty pill in recents).
  os16_rp_overwrite ro.os.tran_hide_status_bar_for_land_recent 1
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
  # Legacy cleanup only when display extras are all off.
  if os16_cfg_bool display_dc true || os16_cfg_bool display_color true \
      || os16_cfg_bool display_hdr true || os16_cfg_bool display_reading false; then
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

os16_restart_systemui() {
  # Do not am crash / killall SystemUI. V1.59 did that at boot and the phone
  # came up then cold-rebooted.
  :
}

os16_restart_surfaceflinger() {
  # Killing SurfaceFlinger after the UI is up is a soft reboot (screen goes
  # black, SystemUI comes back). Blur keys are resetprop'd at post-fs before
  # zygote — a real reboot is the apply path. Do not stop/kill SF.
  :
}

os16_apply_blur_runtime() {
  os16_blur_vals
  os16_settings_put global disable_window_blurs "$DIS"
  os16_settings_put system disable_window_blurs "$DIS"
  if [ "$SOLID_SHADE" = "1" ]; then
    os16_settings_put secure accessibility_reduce_transparency 1
  else
    settings delete secure accessibility_reduce_transparency >/dev/null 2>&1
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
  else
    os16_settings_put global transsion_launcher_gaussian_blur_enable 0
    os16_settings_put system transsion_launcher_gaussian_blur_enable 0
    settings delete system transsion_launcher_blur_radius >/dev/null 2>&1
    settings delete global transsion_launcher_blur_radius >/dev/null 2>&1
  fi
  wm disable-blur "$DIS" >/dev/null 2>&1
  cmd window disable-blur "$DIS" >/dev/null 2>&1
  device_config put systemui notification_shade_blur "$([ "$GLASS" = "1" ] && echo true || echo false)" >/dev/null 2>&1
  if [ "$GLASS" = "1" ] && [ "$BLVL" = "3" ]; then
    device_config put systemui shade_blur_radius 80 >/dev/null 2>&1
  else
    device_config delete systemui shade_blur_radius >/dev/null 2>&1
  fi
}

if [ "${0##*/}" = "apply_blur.sh" ]; then
  mode="${1:-all}"
  case "$mode" in
    props) os16_apply_blur_stack; os16_apply_aod_props; os16_apply_os16_extras_props ;;
    runtime) os16_apply_blur_runtime; os16_apply_aod_settings; os16_apply_dynamicbar_runtime ;;
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
      ;;
  esac
fi
