
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

REPLACE=""

ui_ok()   { ui_print "  ✅ $1"; }
ui_info() { ui_print "  ⚡ $1"; }
ui_warn() { ui_print "  ⚠️  $1"; }
ui_step() { ui_print "  ▶ $1"; }
ui_div()  { ui_print "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

print_modname() {
  ui_print " "
  ui_print "  ╔══════════════════════════════════════════╗"
  ui_print "  ║                                          ║"
  ui_print "  ║    𝙻𝙸𝙻  𝙶  𝚃𝙴𝙲𝙷  𝙻𝙰𝙱𝚂                  ║"
  ui_print "  ║                                          ║"
  ui_print "  ╠══════════════════════════════════════════╣"
  ui_print "  ║                                          ║"
  ui_print "  ║   TRANSSION FLAGSHIP                     ║"
  ui_print "  ║   ALL OS EDITION  ·  V4.24                 ║"
  ui_print "  ║   XOS · HiOS · iTel OS                   ║"
  ui_print "  ║                                          ║"
  ui_print "  ╚══════════════════════════════════════════╝"
  ui_print " "
  ui_print "  > BOOTING LGTL CORE..."
  ui_print "  [ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ]  0%"
  sleep 0.1
  ui_print "  [ ████░░░░░░░░░░░░░░░░░░░░░░░░ ] 15%"
  sleep 0.1
  ui_print "  [ █████████░░░░░░░░░░░░░░░░░░░ ] 33%"
  sleep 0.1
  ui_print "  [ ██████████████░░░░░░░░░░░░░░ ] 50%"
  sleep 0.1
  ui_print "  [ ████████████████████░░░░░░░░ ] 72%"
  sleep 0.1
  ui_print "  [ █████████████████████████░░░ ] 90%"
  sleep 0.1
  ui_print "  [ █████████████████████████████] 100%"
  ui_print " "
  ui_print "  ⚡ CORE ONLINE"
  ui_div
  ui_print " "
}

check_device() {
  ui_step "Validating device..."

  local brand
  brand=$(getprop ro.product.brand | tr '[:upper:]' '[:lower:]')
  local mfr
  mfr=$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
  local model
  model=$(getprop ro.product.model)
  local codename
  codename=$(getprop ro.product.device)

  ui_info "Brand    : $brand"
  ui_info "Model    : $model ($codename)"

  case "$brand$mfr" in
    *infinix*|*tecno*|*itel*|*transsion*)
      ui_ok "Transsion device confirmed"
      ;;
    *)
      ui_warn "Non-Transsion device: $brand"
      abort "  ✖ Aborting — XOS / HiOS / iTel OS required"
      ;;
  esac
}

detect_os() {
  OS_TYPE=$(getprop ro.tran.os.type 2>/dev/null)
  OS_VER=$(getprop ro.transsion.os.version 2>/dev/null)

  if [ -z "$OS_TYPE" ]; then
    local brand
    brand=$(getprop ro.product.brand | tr '[:upper:]' '[:lower:]')
    local desc
    desc=$(getprop ro.build.description | tr '[:upper:]' '[:lower:]')
    case "$desc$brand" in
      *hios*|*tecno*)   OS_TYPE="HiOS" ;;
      *itel*)           OS_TYPE="iTelOS" ;;
      *xos*|*infinix*)  OS_TYPE="XOS" ;;
      *)                OS_TYPE="XOS" ;;
    esac
  fi

  if [ -z "$OS_VER" ]; then
    local desc
    desc=$(getprop ro.build.description)
    case "$desc" in
      *16*) OS_VER="16" ;;
      *15*) OS_VER="15" ;;
      *14*) OS_VER="14" ;;
      *13*) OS_VER="13" ;;
      *12*) OS_VER="12" ;;
      *10*) OS_VER="10" ;;
      *9*)  OS_VER="9"  ;;
      *8*)  OS_VER="8"  ;;
      *)    OS_VER="?"  ;;
    esac
  fi

  ui_info "OS       : $OS_TYPE $OS_VER"

  {
    echo "install_time_utc=$(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    echo "raw_ro.tran.os.type=$(getprop ro.tran.os.type 2>/dev/null)"
    echo "raw_ro.transsion.os.version=$(getprop ro.transsion.os.version 2>/dev/null)"
    echo "raw_ro.product.brand=$(getprop ro.product.brand 2>/dev/null)"
    echo "raw_ro.build.description=$(getprop ro.build.description 2>/dev/null)"
    echo "detected_OS_TYPE=$OS_TYPE"
    echo "detected_OS_VER=$OS_VER"
    echo "used_fallback_detection=$([ -z "$(getprop ro.tran.os.type 2>/dev/null)" ] && echo yes || echo no)"
  } > "$MODPATH/install_diagnostic.txt" 2>/dev/null
}

detect_ram() {
  RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  RAM_GB=$(awk "BEGIN {printf \"%d\", $RAM_KB/1024/1024 + 0.5}")
  ui_info "RAM      : ${RAM_GB}GB"
}

is_xos16() {
  [ "$OS_TYPE" = "XOS" ] || return 1
  echo "$OS_VER" | grep -qiE '^(xos[-_. ]*)?16([^0-9].*)?$'
}

append_os_props() {
  local dest="$MODPATH/system.prop"
  if [ -n "$TMPDIR" ] && [ -f "$TMPDIR/system.prop" ]; then
    dest="$TMPDIR/system.prop"
  fi
  cat >> "$dest"
}

check_module_conflicts() {
  local self_id="transsion-flagship"
  local conflict_paths="system/media/audio/ui system/product/media/audio/ui system/product/media/audio/bootsound system/overlay/FodResOverlay system/overlay/FodSetOverlay system/product/overlay/FodResOverlay system/product/overlay/FodSetOverlay system/overlay/Icons_Signal_wifi system/product/overlay/Icons_Signal_wifi system/product/apm/config system/product/theme/charge system/product/theme/animations system/product/theme/sounds"
  local conflict_props="ro.surface_flinger.supports_background_blur ro.os.recent.blur ro.transsion_recent_animation_support ro.transsion.recent_animation.model ro.transsion_launcher_gaussian_blur_support tr_launcher.gaussianblur.support ro.tran.effectengine.dynamicblur.support ro.surface_flinger.max_frame_buffer_acquired_buffers"
  local found=""
  local d m p k
  for d in /data/adb/modules/*/; do
    [ -d "$d" ] || continue
    m=$(basename "$d")
    [ "$m" = "$self_id" ] && continue
    [ -f "${d}disable" ] && continue
    for p in $conflict_paths; do
      if [ -e "${d}${p}" ]; then
        found="${found}${m}|${p}
"
      fi
    done
    if [ -f "${d}system.prop" ]; then
      for k in $conflict_props; do
        if grep -q "^${k}=" "${d}system.prop" 2>/dev/null; then
          found="${found}${m}|prop:${k}
"
        fi
      done
    fi
  done

  mkdir -p /data/adb/transsion-flagship-staging
  printf '%s' "$found" > /data/adb/transsion-flagship-staging/install_conflicts.txt

  if [ -z "$found" ]; then
    ui_ok "No conflicting modules detected"
    return
  fi

  local mods
  mods=$(printf '%s' "$found" | cut -d'|' -f1 | sort -u)
  ui_warn "Possible conflicts with other installed modules:"
  local mod
  for mod in $mods; do
    ui_warn "  - $mod"
  done
  ui_info "Open the TransFlagship WebUI after reboot to review and remove"
  ui_info "conflicting modules if needed — nothing has been touched."
}

on_install() {
  ui_print " "
  ui_div
  ui_step "Running Pre-Flight Checks..."
  ui_div

  check_device
  detect_os
  detect_ram

  ui_print " "
  ui_div
  ui_step "Checking for Module Conflicts..."
  ui_div

  check_module_conflicts

  ui_print " "
  ui_div
  ui_step "Injecting System Files..."
  ui_div

  unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'config.json' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'CHANGELOG.md' -d "$MODPATH" >&2

  unzip -oj "$ZIPFILE" 'common/system.prop' -d "$MODPATH" >&2

  CFG=/data/adb/modules/transsion-flagship/config.json
  if [ -f "$CFG" ]; then
    ui_step "Existing config found — preserving user settings..."
    sed -e '/"anim_master"/d' -e '/"anim_unlock"/d' -e '/"anim_unlock_level"/d' \
        -e '/"anim_recent"/d' -e '/"anim_recent_level"/d' \
        -e '/"anim_launch"/d' -e '/"anim_launch_level"/d' \
        -e '/"anim_dream"/d' -e '/"anim_folder"/d' \
        -e '/"anim_blur"/d' -e '/"anim_blur_level"/d' -e '/"anim_arc"/d' \
        "$CFG" > "$MODPATH/config.json" 2>/dev/null || cp -af "$CFG" "$MODPATH/config.json"
    ui_ok "Config preserved (stale animation keys cleaned up)"
  else
    ui_step "Writing default config..."
    cat > "$MODPATH/config.json" << 'DEFAULTCFG'
{
  "boot_sound": true,
  "boot_sound_name": "Waltz",
  "bootanim_style": "default",
  "shutdownanim_style": "default",
  "charge_anim": true,
  "chargesound_style": "default",
  "wirelesschargesound_style": "default",
  "emoji_font": true,
  "ai_master": true,
  "ai_subtitles": true,
  "ai_call_summary": true,
  "ai_notif_summary": true,
  "ai_sound_rec": true,
  "ai_notes": true,
  "game_master": true,
  "game_esports_touch": true,
  "game_esports_level": 3,
  "game_interpolation": true,
  "game_raytracing": true,
  "game_hdr": true,
  "game_bypass_charge": true,
  "social_master": true,
  "social_record": true,
  "social_translate": true,
  "social_beauty": true,
  "display_dc": true,
  "display_color": true,
  "display_hdr": true,
  "display_reading": false,
  "nav_hide": false,
  "aod": true,
  "launcher_blur": true,
  "perf_tuning": false,
  "force_120hz": false,
  "statusbar_style": "xos16",
  "fod_animation": true
}
DEFAULTCFG
    if is_xos16; then
      sed -i \
        -e 's/"charge_anim": true/"charge_anim": false/' \
        -e 's/"fod_animation": true/"fod_animation": false/' \
        -e 's/"statusbar_style": "xos16"/"statusbar_style": "off"/' \
        "$MODPATH/config.json"
      ui_ok "XOS 16 defaults: charging anim, fingerprint anim, and status bar overlay off"
    else
      ui_ok "Default config written"
    fi
  fi

  if [ "$OS_TYPE" != "XOS" ]; then
    ui_step "Non-XOS device — removing XOS-exclusive APKs..."
    rm -rf "$MODPATH/system/system_ext/app/Astronaut"
    rm -rf "$MODPATH/system/system_ext/app/ZeroScreen"
    ui_ok "Astronaut + ZeroScreen skipped (XOS only)"
  else
    ui_ok "XOS detected — Astronaut + ZeroScreen included"
  fi

  if [ "$OS_TYPE" = "HiOS" ]; then
    ui_step "HiOS detected — configuring HiOS asset paths..."
    rm -f "$MODPATH/system/product/media/bootanimation.zip"
    rm -f "$MODPATH/system/product/media/shutdownanimation.zip"
    mkdir -p "$MODPATH/system/media/audio/bootsound"
    cp "$MODPATH/system/media/audio/ui/Waltz.ogg" "$MODPATH/system/media/audio/bootsound/Waltz.ogg" 2>/dev/null || true
    ui_ok "HiOS asset paths configured"
  fi

  ui_step "Selecting APM memory profile (${RAM_GB}GB RAM)..."
  if [ "$RAM_GB" -ge 12 ]; then
    rm -f "$MODPATH/system/product/apm/config/memory/appmemory_limit_config_8g.json"
    ui_ok "12GB memory profile active"
  else
    rm -f "$MODPATH/system/product/apm/config/memory/appmemory_limit_config_12g.json"
    ui_ok "8GB memory profile active"
  fi

  case "$OS_TYPE" in
    XOS)
      if is_xos16; then
          ui_step "Applying XOS 16 Extended Props..."
          append_os_props << 'XOSPROP'

ro.os_ai_nova_support=1
ro.os_ai_nova_v2_support=1
ro.os_ai_copilot_support=1
ro.os_ai_copilot_v2_support=1
ro.os_ai_proactive_suggest_support=1
ro.os_ai_smart_reply_support=1
ro.os_ai_text_action_support=1
ro.os_ai_circle_to_search_support=1
ro.os_ai_live_translate_support=1
ro.tran.ai.vision.support=1
ro.tran.ai.vision.v2.support=1
ro.tran.hyper_engine_v5.support=1
ro.os_game_hyper_boost.support=1
ro.os_game_ai_fps_boost.support=1
ro.os_xos16_blur_v2_support=1
ro.os_spatial_audio_support=1
ro.os_smart_cutout_support=1
ro.os_privacy_dashboard_v2_support=1
ro.tran.secure_folder_v2_support=1
ro.tran.ai_portrait_v3_support=1
ro.tran.ai_night_v3_support=1
ro.os_camera_hyper_ai_support=1
XOSPROP
          ui_ok "XOS 16 props injected"
          VCONFIG_DIR="$MODPATH/system/tr_product/etc/vconfig/com.transsion.launcher3"
          mkdir -p "$VCONFIG_DIR"
          cat > "$VCONFIG_DIR/build.prop" << 'VCONFIGPROP'
ro.tr_perf.launch_start_exit.model=3
ro.os.tran_hide_status_bar_for_land_recent=1
VCONFIGPROP
          ui_ok "XOS 16 launcher vconfig applied (app open/close animation)"
      else
        case "$OS_VER" in
          15*)
            ui_step "Applying XOS 15 Extended Props..."
            append_os_props << 'XOSPROP'

ro.os_ai_nova_support=1
ro.os_ai_copilot_support=1
ro.tran.hyper_engine_v4.support=1
ro.os_game_hyper_boost.support=1
ro.os_xos15_blur_support=1
ro.tran.ai_portrait_v2_support=1
ro.tran.ai_night_v2_support=1
XOSPROP
            ui_ok "XOS 15 props injected"
            ;;
          *)
            ui_ok "XOS $OS_VER base props active"
            ;;
        esac
      fi
      ;;

    HiOS)
      ui_step "Applying HiOS Extended Props..."
      append_os_props << 'HIOSPROP'

ro.tran_hios_launcher_support=1
ro.tran_hios_dynamic_bar_support=1
ro.tran_hios_ai_gallery_support=1
ro.tran_hios_magic_ringtone_support=1
ro.tran_hios_smart_panel_support=1
ro.tran_hios_one_hand_support=1
ro.tran_hios_screen_translate_support=1
ro.tran_hios_smart_connect_support=1
ro.tran.ai_phone_hios.support=1
HIOSPROP
      ui_ok "HiOS props injected"
      ;;

    iTelOS)
      ui_step "Applying iTel OS Extended Props..."
      append_os_props << 'ITELPROP'

ro.tran_itel_launcher_support=1
ro.tran_itel_smart_key_support=1
ro.tran_itel_battery_saver_v2_support=1
ro.tran_itel_data_saver_support=1
ro.tran_itel_ai_gallery_support=1
ITELPROP
      ui_ok "iTel OS props injected"
      ;;
  esac

  ui_print " "
  ui_ok "WebUI available in Magisk/KSU Manager"
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644

  for f in \
    "$MODPATH/system/fonts/NotoColorEmoji.ttf" \
    "$MODPATH/system/product/fonts/NotoColorEmoji.ttf"; do
    [ -f "$f" ] && set_perm "$f" 0 0 0644
  done

  for apk in $(find "$MODPATH/system" -name "*.apk" 2>/dev/null); do
    set_perm "$apk" 0 0 0644
  done

  for sh in \
    "$MODPATH/post-fs-data.sh" \
    "$MODPATH/service.sh" \
    "$MODPATH/uninstall.sh"; do
    [ -f "$sh" ] && set_perm "$sh" 0 0 0755
  done

  ui_print " "
  ui_div
  ui_print "  ✨  INSTALLATION COMPLETE"
  ui_info "Module : Transsion Flagship V4.24"
  ui_info "Author : LIL G TECH LABS"
  ui_info "OS     : $OS_TYPE $OS_VER"
  ui_info "RAM    : ${RAM_GB}GB"
  ui_div
  ui_print "  📲  t.me/LilGTechLabs"
  ui_print " "
  ui_print "  ⚡ Reboot to activate all features"
  ui_print " "
  ui_ok "WebUI available in Magisk/KSU Manager"
}
