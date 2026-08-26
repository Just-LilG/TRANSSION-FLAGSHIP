
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
  ui_print "  ║    TRANSSION FLAGSHIP 16                 ║"
  ui_print "  ║    XOS · HiOS · iTel OS 16  ·  V1.20     ║"
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
    sed -i -e 's/"statusbar_style": *"ios"/"statusbar_style": "off"/' \
           -e 's/"statusbar_style": *"xos16"/"statusbar_style": "off"/' \
           -e 's/"ai_master": true/"ai_master": false/' \
           "$MODPATH/config.json"
  else
    ui_ok "Default config: HiOS 16 boot + reboot, AI off, status bar stock"
  fi

  ui_ok "Boot animation"
  ui_ok "Reboot animation"
  ui_ok "Status bar: upload your own overlay, or leave stock"
  ui_ok "Home: Dump AI flags, then Copy log"
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  for sh in "$MODPATH/post-fs-data.sh" "$MODPATH/service.sh" "$MODPATH/uninstall.sh"; do
    [ -f "$sh" ] && set_perm "$sh" 0 0 0755
  done
  ui_print " "
  ui_div
  ui_print "  ✨  FLAGSHIP 16  ·  V1.20"
  ui_info "OS     : $OS_TYPE $OS_VER"
  ui_info "Feature: boot + reboot + overlay + AI dump + copy log"
  ui_div
  ui_print "  Reboot, then open WebUI in Magisk/KSU."
  ui_print " "
}
