
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

json_bool() {
  f="$1"; k="$2"; d="$3"
  [ -f "$f" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$f" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

ai_01() {
  cfg="$1"; master="$2"; key="$3"; def="$4"
  [ "$master" = "true" ] || { echo 0; return; }
  v=$(json_bool "$cfg" "$key" "$def")
  [ "$v" = "false" ] && echo 0 || echo 1
}

ai_tf() {
  cfg="$1"; master="$2"; key="$3"; def="$4"
  [ "$master" = "true" ] || { echo false; return; }
  v=$(json_bool "$cfg" "$key" "$def")
  [ "$v" = "false" ] && echo false || echo true
}

write_os16_ai_prop() {
  cfg="$1"
  dest="$2"
  master=$(json_bool "$cfg" ai_master true)
  sub=$(ai_01 "$cfg" "$master" ai_subtitles true)
  rec=$(ai_01 "$cfg" "$master" ai_sound_rec true)
  notes=$(ai_01 "$cfg" "$master" ai_notes true)
  writing=$(ai_01 "$cfg" "$master" ai_writing true)
  call=$(ai_tf "$cfg" "$master" ai_call_summary false)
  gal=$(ai_01 "$cfg" "$master" ai_gallery true)
  vee=$(ai_01 "$cfg" "$master" ai_video true)
  cat > "$dest" <<EOF
# Flagship 16 — OS 16 AI keys. Magisk loads this file at boot.
# Apply in WebUI rewrites this file from the AI Suite toggles. Reboot to take effect.
# Not written from service.sh.
ro.tr_aiservice.aicorespeech_subtitle.feature.support=$sub
ro.tr_aiservice.aicorespeech_livecaption.feature.support=$sub
ro.tr_soundrecorder.summary.feature.support=$rec
ro.tr_note.ai_draw.support=$notes
ro.os_ai_writing.support=$writing
ro.tr_aiassistant.aiphone.feature.support=$call
ro.tr_aiassistant.aiphone_summany.feature.support=$call
ro.tr_gallery.ai_art.support=$gal
ro.tr_gallery.ai.studio.lite.support=$gal
ro.tr_gallery.eraser.v2.support=$gal
ro.tr_gallery.ext.image.support=$gal
ro.tr_gallery.hd.support=$gal
ro.tr_gallery.group.enhance.support=$gal
ro.tr_gallery.shadow.enhance.support=$gal
ro.tr_gallery.bokeh.support=$gal
ro.tr_gallery.compose.support=$gal
ro.tr_video.vee.support=$vee
EOF
}

print_modname() {
  ui_print " "
  ui_print "  ╔══════════════════════════════════════════╗"
  ui_print "  ║    TRANSSION FLAGSHIP 16                 ║"
  ui_print "  ║    XOS · HiOS · iTel OS 16  ·  V1.23     ║"
  ui_print "  ╚══════════════════════════════════════════╝"
  ui_print " "
}

detect_os16() {
  OS_TYPE=$(getprop ro.tran.os.type 2>/dev/null)
  OS_VER=$(getprop ro.transsion.os.version 2>/dev/null)
  BRAND=$(getprop ro.product.brand | tr '[:upper:]' '[:lower:]')
  ANDROID=$(getprop ro.build.version.release 2>/dev/null)
  DESC=$(getprop ro.build.description 2>/dev/null)

  if [ -z "$OS_TYPE" ]; then
    case "$BRAND" in
      *tecno*) OS_TYPE="HiOS" ;;
      *itel*)  OS_TYPE="iTelOS" ;;
      *)       OS_TYPE="XOS" ;;
    esac
  fi

  branded=$(echo "$DESC $OS_VER" | grep -oiE '(xos|hios|itelos|itel)[-_. ]*[0-9]+' | head -1)
  if echo "$OS_VER" | grep -qiE '^(xos[-_. ]*)?16([^0-9].*)?$'; then
    OS_VER=16
  elif [ -n "$branded" ] && echo "$branded" | grep -q '16'; then
    OS_VER=16
  elif [ -d /tr_product ] && echo "$ANDROID" | grep -q '^16'; then
    OS_VER=16
  elif [ -z "$OS_VER" ]; then
    OS_VER="?"
  fi
}

on_install() {
  ui_print " "
  ui_div
  ui_step "Validating device..."
  ui_div

  brand=$(getprop ro.product.brand | tr '[:upper:]' '[:lower:]')
  mfr=$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
  model=$(getprop ro.product.model)
  ui_info "Brand : $brand"
  ui_info "Model : $model"
  case "$brand$mfr" in
    *infinix*|*tecno*|*itel*|*transsion*)
      ui_ok "Transsion device confirmed"
      ;;
    *)
      abort "  ✖ Aborting — Infinix / Tecno / itel required"
      ;;
  esac

  detect_os16
  ui_info "OS    : $OS_TYPE $OS_VER"
  ui_info "Android: $(getprop ro.build.version.release 2>/dev/null)"
  ui_info "/tr_product : $([ -d /tr_product ] && echo present || echo missing)"

  if [ "$OS_VER" != "16" ]; then
    ui_warn "Could not confirm OS 16 — this module is built for Transsion OS 16."
    ui_warn "Continuing anyway if you flashed it on purpose."
  else
    ui_ok "Transsion OS 16 detected"
  fi

  {
    echo "install_time_utc=$(date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    echo "raw_ro.tran.os.type=$(getprop ro.tran.os.type 2>/dev/null)"
    echo "raw_ro.transsion.os.version=$(getprop ro.transsion.os.version 2>/dev/null)"
    echo "raw_ro.product.brand=$(getprop ro.product.brand 2>/dev/null)"
    echo "raw_ro.build.description=$(getprop ro.build.description 2>/dev/null)"
    echo "detected_OS_TYPE=$OS_TYPE"
    echo "detected_OS_VER=$OS_VER"
    echo "tr_product=$([ -d /tr_product ] && echo yes || echo no)"
  } > "$MODPATH/install_diagnostic.txt"

  OLD=/data/adb/modules/transsion-flagship
  if [ -d "$OLD" ] && [ ! -f "$OLD/disable" ]; then
    touch "$OLD/disable"
    ui_warn "Disabled Flagship 15 (transsion-flagship) so it cannot fight this module."
    ui_info "Uninstall Flagship 15 from Magisk/KSU after reboot."
  fi

  ui_print " "
  ui_div
  ui_step "Injecting files..."
  ui_div
  # KernelSU already unpacked the zip. Re-unzipping system/* (two 6–13MB
  # bootanim archives) is what got the V1.05 flash "Killed" (OOM).
  have_zips=false
  if [ -f "$MODPATH/system/product/theme/animations/bootanim_hios16.zip" ] \
      && [ -f "$MODPATH/system/product/theme/animations/bootanim_default.zip" ]; then
    have_zips=true
  fi
  if [ "$KEEP_EXTRACT" = true ] || [ "$have_zips" = true ]; then
    ui_ok "Boot animation zips already extracted"
    ui_info "Refreshing scripts and webroot"
    unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'config.json' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'CHANGELOG.md' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/system.prop' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'tr_product/*' -d "$MODPATH" >&2
  else
    ui_info "Extracting module files from zip"
    unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'tr_product/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'config.json' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'CHANGELOG.md' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/system.prop' -d "$MODPATH" >&2
  fi

  # Drop failed boot-sound / charging packs left by V1.02–V1.12.
  rm -rf "$MODPATH/system/product/theme/charge" \
         "$MODPATH/tr_product/theme/charge" \
         "$MODPATH/product/theme/charge" \
         "$MODPATH/system/product/media/audio" \
         "$MODPATH/tr_product/media/audio" \
         "$MODPATH/product/media/audio" \
         "$MODPATH/.charge_tr" "$MODPATH/.charge_prod"
  rm -f "$MODPATH/.charge_pick.mp4" "$MODPATH/charge_custom.mp4"
  rm -rf /mnt/vendor/mountify/tr_product/theme/charge \
         /mnt/vendor/mountify/product/theme/charge \
         /mnt/vendor/mountify/tr_product/media/audio/bootsound
  rm -f /data/local/bootaudio.mp3 /data/local/shutaudio.mp3
  ui_ok "Removed unused charging and boot-sound files"

  # V1.14 shipped bundled iOS / XOS 16 overlay APKs. Drop them; keep a custom
  # upload if the user already wrote one.
  rm -rf "$MODPATH/system/overlay/Icons_Signal_wifi" \
         "$MODPATH/system/product/overlay/Icons_Signal_wifi" \
         "$MODPATH/product/overlay/Icons_Signal_wifi" \
         /mnt/vendor/mountify/system/overlay/Icons_Signal_wifi \
         /mnt/vendor/mountify/system/product/overlay/Icons_Signal_wifi \
         /mnt/vendor/mountify/product/overlay/Icons_Signal_wifi
  rm -f "$MODPATH/system/overlay/SystemUISignalOverlay.apk" \
        "$MODPATH/system/overlay/SystemUISignalOverlay.apk.disabled" \
        "$MODPATH/system/product/overlay/SystemUISignalOverlay.apk" \
        "$MODPATH/system/product/overlay/SystemUISignalOverlay.apk.disabled" \
        "$MODPATH/product/overlay/SystemUISignalOverlay.apk" \
        "$MODPATH/product/overlay/SystemUISignalOverlay.apk.disabled" \
        /mnt/vendor/mountify/system/overlay/SystemUISignalOverlay.apk \
        /mnt/vendor/mountify/system/overlay/SystemUISignalOverlay.apk.disabled \
        /mnt/vendor/mountify/system/product/overlay/SystemUISignalOverlay.apk \
        /mnt/vendor/mountify/system/product/overlay/SystemUISignalOverlay.apk.disabled \
        /mnt/vendor/mountify/product/overlay/SystemUISignalOverlay.apk \
        /mnt/vendor/mountify/product/overlay/SystemUISignalOverlay.apk.disabled
  ui_ok "Removed bundled status-bar overlay APKs"

  CFG=/data/adb/modules/transsion-flagship-16/config.json
  if [ -f "$CFG" ]; then
    ui_ok "Existing Flagship 16 config preserved"
    cp "$CFG" "$MODPATH/config.json"
    # Keep existing AI toggles. Rename the old Notification Summary key.
    sed -i -e 's/"statusbar_style": *"ios"/"statusbar_style": "off"/' \
           -e 's/"statusbar_style": *"xos16"/"statusbar_style": "off"/' \
           -e 's/"ai_notif_summary"/"ai_writing"/' \
           "$MODPATH/config.json"
  else
    ui_ok "Default config: HiOS 16 boot + reboot, AI on, status bar stock"
  fi
  write_os16_ai_prop "$MODPATH/config.json" "$MODPATH/system.prop"
  ui_ok "OS 16 AI keys written from config (reboot to apply)"

  ui_ok "Boot animation"
  ui_ok "Reboot animation"
  ui_ok "Status bar: upload your own overlay, or leave stock"
  ui_ok "OS 16 AI Suite — Apply in WebUI, then reboot"
}

set_permissions() {
  # Magisk copies zip system.prop after on_install. Rewrite from config so
  # WebUI toggles survive an upgrade.
  write_os16_ai_prop "$MODPATH/config.json" "$MODPATH/system.prop"
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  for sh in "$MODPATH/post-fs-data.sh" "$MODPATH/service.sh" "$MODPATH/uninstall.sh"; do
    [ -f "$sh" ] && set_perm "$sh" 0 0 0755
  done
  ui_print " "
  ui_div
  ui_print "  ✨  FLAGSHIP 16  ·  V1.23"
  ui_info "OS     : $OS_TYPE $OS_VER"
  ui_info "Feature: boot + reboot + overlay + OS 16 AI Suite"
  ui_div
  ui_print "  Reboot, then open WebUI in Magisk/KSU."
  ui_print " "
}
