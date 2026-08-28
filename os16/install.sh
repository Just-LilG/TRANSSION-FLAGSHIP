
# Mountify copies system/* itself. Magisk magic-mount of /system fights that
# overlay and still never reaches /tr_product (bootanim already bind-mounts).
SKIPMOUNT=true
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

json_int() {
  f="$1"; k="$2"; d="$3"
  v=$(json_bool "$f" "$k" "$d")
  case "$v" in
    ''|*[!0-9]*) echo "$d" ;;
    *) echo "$v" ;;
  esac
}

write_os16_ai_prop() {
  cfg="$1"
  dest="$2"
  master=$(json_bool "$cfg" ai_master true)
  sub=$(ai_01 "$cfg" "$master" ai_subtitles true)
  rec=$(ai_01 "$cfg" "$master" ai_sound_rec true)
  notes=$(ai_01 "$cfg" "$master" ai_notes true)
  writing=$(ai_01 "$cfg" "$master" ai_writing true)
  call=$(ai_tf "$cfg" "$master" ai_call_summary true)
  gal=$(ai_01 "$cfg" "$master" ai_gallery true)
  vee=$(ai_01 "$cfg" "$master" ai_video true)
  gmaster=$(json_bool "$cfg" game_master true)
  gtouch=$(ai_01 "$cfg" "$gmaster" game_esports_touch true)
  gbypass=$(ai_01 "$cfg" "$gmaster" game_bypass_charge true)
  gtrig=$(ai_01 "$cfg" "$gmaster" game_gt_triggers true)
  gtrig_tf=$(ai_tf "$cfg" "$gmaster" game_gt_triggers true)
  smaster=$(json_bool "$cfg" social_master true)
  srec=$(ai_01 "$cfg" "$smaster" social_record true)
  strans=$(ai_01 "$cfg" "$smaster" social_translate true)
  sbeau=$(ai_01 "$cfg" "$smaster" social_beauty true)
  smode=0
  sdefoff=1
  sbeau_dis=1
  if [ "$smaster" = "true" ]; then
    smode=1
    sdefoff=0
  fi
  [ "$sbeau" = "1" ] && sbeau_dis=0
  ddc=$(json_bool "$cfg" display_dc true)
  dcol=$(json_bool "$cfg" display_color true)
  dhdr=$(json_bool "$cfg" display_hdr true)
  dread=$(json_bool "$cfg" display_reading false)
  [ "$ddc" = "false" ] && ddc=0 || ddc=1
  [ "$dcol" = "false" ] && dcol=0 || dcol=1
  [ "$dhdr" = "false" ] && dhdr=0 || dhdr=1
  [ "$dread" = "true" ] && dread=1 || dread=0
  scale=$(json_bool "$cfg" scale_os16 true)
  [ "$scale" = "false" ] && scale=false || scale=true
  gt=$(json_bool "$cfg" gt_apps_os16 true)
  circle=$(json_bool "$cfg" circle_os16 true)
  motion=$(json_bool "$cfg" motion_sick_os16 true)
  [ "$gt" = "false" ] && gt01=0 || gt01=1
  [ "$gt" = "false" ] && gttrue=false || gttrue=true
  [ "$circle" = "false" ] && circle=0 || circle=1
  [ "$motion" = "false" ] && motion=0 || motion=1
  glvl=$(json_int "$cfg" game_esports_level 3)
  [ "$glvl" -ge 1 ] 2>/dev/null || glvl=3
  [ "$glvl" -le 3 ] 2>/dev/null || glvl=3
  g10=0; g20=0; g30=0; g11=0; gemode=0
  if [ "$gmaster" = "true" ]; then
    gemode=1
    if [ "$gtouch" = "1" ]; then
      g10=1
      g11=1
      [ "$glvl" -ge 2 ] && g20=1
      [ "$glvl" -ge 3 ] && g30=1
    fi
  fi
  anim=$(json_bool "$cfg" anim_os16 true)
  blur=$(json_bool "$cfg" blur_os16 true)
  blvl=0
  if [ "$blur" = "true" ]; then
    blvl=$(json_int "$cfg" blur_os16_level 2)
    [ "$blvl" -ge 1 ] 2>/dev/null || blvl=2
    [ "$blvl" -le 3 ] 2>/dev/null || blvl=2
  fi
  # Parallel motion stays at platform 3 whenever Parallel is on.
  # Unionrender only at blur level 2/3 (glass tier).
  if [ "$anim" = "true" ]; then
    a01=1
    alvl=3
  else
    a01=0
    alvl=0
  fi
  union=0
  b01=0
  sfdis=1
  gblur=0
  dynblur=0
  blurv2=0
  exp=0
  launcher_async=0
  if [ "$blur" = "true" ]; then
    case "$blvl" in
      1) b01=0; sfdis=1; gblur=2; dynblur=0; blurv2=0; exp=0; launcher_async=0; union=0 ;;
      2) b01=1; sfdis=0; gblur=2; dynblur=0; blurv2=0; exp=0; launcher_async=$a01; union=$a01 ;;
      3) b01=1; sfdis=0; gblur=3; dynblur=1; blurv2=1; exp=1; launcher_async=$a01; union=$a01 ;;
      *) b01=1; sfdis=0; gblur=2; dynblur=0; blurv2=0; exp=0; launcher_async=$a01; union=$a01 ;;
    esac
  else
    b01=0; sfdis=1; gblur=2; dynblur=0; blurv2=0; exp=0; launcher_async=0; union=0
  fi
  aod=$(json_bool "$cfg" aod_os16 true)
  dbar=$(json_bool "$cfg" dynamicbar_os16 false)
  sr=$(json_bool "$cfg" videosr_os16 true)
  sv=$(json_bool "$cfg" supervol_os16 true)
  box=$(json_bool "$cfg" treasure_os16 true)
  pet=$(json_bool "$cfg" cutepet_os16 true)
  outdoor=$(json_bool "$cfg" outdoorboost_os16 true)
  glive=$(json_bool "$cfg" gallerylive_os16 true)
  airt=$(json_bool "$cfg" airtransfer_os16 true)
  [ "$aod" = "false" ] && aod=0 || aod=1
  [ "$sr" = "false" ] && sr=0 || sr=1
  [ "$sv" = "false" ] && sv=false || sv=true
  [ "$box" = "false" ] && box=0 || box=1
  [ "$pet" = "false" ] && pet=0 || pet=1
  [ "$outdoor" = "false" ] && outdoor=0 || outdoor=1
  [ "$glive" = "false" ] && glive=0 || glive=1
  [ "$airt" = "false" ] && airt=0 || airt=1
  cat > "$dest" <<EOF
# Flagship 16 — OS 16 keys. Magisk loads this file at boot.
# Apply in WebUI rewrites this file from the Features toggles.
# Blur keys that already exist in /tr_product/etc/build.prop are also
# resetprop'd from apply_blur.sh (post-fs-data + late_start + WebUI).
ro.tr_aiservice.aicorespeech_subtitle.feature.support=$sub
ro.tr_aiservice.aicorespeech_livecaption.feature.support=$sub
ro.tr_soundrecorder.summary.feature.support=$rec
ro.tr_note.ai_draw.support=$notes
ro.os_ai_writing.support=$writing
ro.tr_aiassistant.aiphone.feature.support=$call
ro.tr_aiassistant.aiphone_summany.feature.support=$call
ro.tr_gallery.eraser.v2.support=$gal
ro.tr_gallery.ext.image.support=$gal
ro.tr_gallery.ai_art.support=$gal
ro.tr_gallery.ai.studio.lite.support=$gal
ro.tr_gallery.hd.support=$gal
ro.tr_gallery.group.enhance.support=$gal
ro.tr_gallery.shadow.enhance.support=$gal
ro.tr_gallery.bokeh.support=$gal
ro.tr_gallery.compose.support=$gal
ro.tr_video.vee.support=$vee
ro.tr_game.e_sport_mode.support=$gemode
ro.tr_game.game_mode.support=$gemode
ro.tr_game.tp_esports10.feature.support=$g10
ro.tr_game.tp_esports20.feature.support=$g20
ro.tr_game.tp_esports30.feature.support=$g30
ro.tr_game.esports_update11.support=$g11
ro.tr_game.bypass_charging.support=$gbypass
ro.tr_game.shoulder_key.support=$gtrig
ro.tr_game.ai_picture_triggers.support=$gtrig
ro.tr_game.esportsvirtualctrl.support=$gtrig
ro.tr_game.screen_buttons.support=$gtrig
ro.tr_game.magic_button.support=$gtrig
ro.tr_smartbutton.shoulderbutton20.feature.support=$gtrig_tf
ro.tr_social.turbo_mode.support=$smode
ro.tr_social.record.support=$srec
ro.tr_social.call_translator.support=$strans
ro.tr_social.call_summary.support=$strans
ro.tr_social.sound_change.support=$srec
ro.tr_socialturbo.makeup.support=$sbeau
ro.tr_social.beauty_disable.support=$sbeau_dis
ro.tr_social.default_off.support=$sdefoff
ro.tr_display.sdr2hdr.support=$dhdr
ro.tr_light.xdr.support=$dhdr
ro.tr_light.xdr.v2.support=$dhdr
ro.tran.display_hdr_support=$dhdr
ro.tran.display_dc_dimming_support=$ddc
ro.surface_flinger.has_HDR_display=$([ "$dhdr" = "1" ] && echo true || echo false)
ro.tr_display.colormode.feature.support=$dcol
ro.tr_display.color.temperature.feature.support=$dcol
persist.tr_display.color.temperature.aosp.support=$dcol
ro.tr_animation.platform_level=$alvl
ro.tr_perf.launch_start_exit.model=$alvl
ro.tr_perf.power_keyguard_animation.model=$alvl
ro.tr_perf.recent_animation.model=$alvl
ro.tr_perf.unlock_mode.model=$alvl
ro.tr_livewallpaper.dreamanimation.support=$a01
ro.tr_multiwindow.anim_arc.support=$a01
ro.transsion_async_animation_support=$launcher_async
ro.transsion_unlock_mode_support=$alvl
ro.transsion_launch_start_exit_support=$alvl
ro.transsion_power_keyguard_animation_support=$alvl
ro.transsion.recent_animation.model=$alvl
ro.tran_display_unionrender.support=$union
ro.tr_display.liquidglass.support=$b01
ro.surface_flinger.supports_background_blur=$b01
ro.os.recent.blur=$b01
ro.transsion_launcher_gaussian_blur_support=$gblur
tr_launcher.gaussianblur.support=$gblur
ro.tran.effectengine.dynamicblur.support=$dynblur
ro.os_xos16_blur_v2_support=$blurv2
persist.sys.sf.disable_blurs=$sfdis
persist.sys.disable_blur=$sfdis
persist.sysui.disableBlur=$sfdis
persist.sysui.disable_blur=$sfdis
ro.sf.blurs_are_expensive=$exp
ro.tr_aod.feature.support=$aod
ro.tr_aod.doze.brightness.feature.support=$aod
ro.tr_aod.half.screen.feature.support=$aod
tr_aod.horizontal.display.feature.support=$aod
ro.tr_aod.horizontal.display.feature.support=$aod
tr_aod.always.show.feature.support=$aod
ro.tr_aod.always.show.feature.support=$aod
ro.aod_alwaysshow_support=$aod
ro.tran_aod_v3_support=$aod
ro.tran_doze_brightness_support=$aod
persist.tr_video.ai_super_resolution.support=$sr
ro.tr_video.ai_super_resolution.support=$sr
tr_video.ai_super_resolution.support=$sr
ro.tr_audio.supervol.feature.support=$sv
tr_audio.supervol.feature.support=$sv
ro.tr_ai_treasure_box.feature.support=$box
tr_ai_treasure_box.feature.support=$box
ro.tr_cutepet.feature.support=$pet
tr_cutepet.feature.support=$pet
ro.os_cutepet_support=$pet
ro.tr_outdoorboost.feature.support=$outdoor
tr_outdoorboost.feature.support=$outdoor
tr_gallery.live.support=$glive
tr_gallery.live.slow.support=$glive
ro.tr_gallery.live.support=$glive
ro.tr_gallery.live.slow.support=$glive
ro.tr_airtransfer.feature.support=$airt
tr_airtransfer.feature.support=$airt
tr_display.resolution.scalingup.support=$scale
ro.tr_display.resolution.scalingup.support=$scale
tr_gallery.3dphoto.support=$gt01
tr_gallery.custom.fliters.support=$gt01
tr_gallery.drag.sort.support=$gt01
tr_gallery.easypic.support=$gt01
tr_gallery.matting.support=$gt01
tr_gallery.photo.16grid.support=$gt01
tr_gallery.photo.8grid.support=$gt01
tr_gallery.photo.cover.support=$gt01
tr_gallery.photo.feature.support=$gt01
tr_gallery.search.support=$gt01
tr_gallery.soft.player.support=$gt01
tr_soundrecorder.speech.feature.support=$gt01
tr_smartscan.ar_measure.support=$gttrue
tr_smartscan.document_scan.support=$gttrue
tr_smartscan.medicine_verification.support=$gttrue
tr_smartscan.recharge.support=$gttrue
tr_microIntelligence.gesture_functions.feature.support=$gt01
ro.tr_microIntelligence.gesture_functions.feature.support=$gt01
ro.tr_microIntelligence.microIntelligence.feature.support=$gt01
tr_pcconnect.extend_screen.feature.support=$gttrue
tr_pcconnect.backup.feature.support=$gt01
tr_pcconnect.gesture_file_transfer.feature.support=$gt01
tr_pcconnect.network_sharing.feature.support=$gt01
tr_pcconnect.pc_mouse_button.feature.support=$gt01
ro.tr_pcconnect.feature.support=$gt01
tr_zeroscreen.ai.card.support=$gt01
tr_globalsearch.easypic.support=$gt01
ro.tr_smartpanel.os_smartpanel.support=$gt01
ro.tr_smartpanel.os_slider_panel.support=$gt01
ro.tr_smartpanel.os_slider_panel_default_close.config=0
ro.tr_smartpanel.os_smart_hub_def_off.config=0
ro.tr_dialer.contact.carlcare.feature.support=$gt01
ro.tr_microIntelligence.circle_to_search.feature.support=$circle
tr_microIntelligence.circle_to_search.feature.support=$circle
ro.os_ai_circle_to_search_support=$circle
ro.tr_microIntelligence.motion_sickness.feature.support=$motion
tr_microIntelligence.motion_sickness.feature.support=$motion
ro.surface_flinger.game_default_frame_rate_override=120
debug.graphics.game_default_frame_rate.disabled=true
persist.graphics.game_default_frame_rate.enabled=false
EOF
  if [ "$dbar" = "true" ]; then
    cat >> "$dest" <<EOF
ro.tr_dynamicbar.support=1
ro.os_dynamicbar_ai_translation_support=1
ro.os_dynamic_bar_resident_plane_support=1
ro.os.tran_hide_status_bar_for_land_recent=1
ro.tran_hios_dynamic_bar_support=1
EOF
  fi
}

print_modname() {
  ui_print " "
  ui_print "  ╔══════════════════════════════════════════╗"
  ui_print "  ║    TRANSSION FLAGSHIP 16                 ║"
    ui_print "  ║    XOS · HiOS · iTel OS 16  ·  V1.87     ║"
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
    unzip -oj "$ZIPFILE" 'common/apply_blur.sh' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_120hz.sh' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_sounds.sh' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_unlock.sh' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'apm_120hz_bypass/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'magellan/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'system/product/apm/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'system/tr_product/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'tr_product/*' -d "$MODPATH" >&2
  else
    ui_info "Extracting module files from zip"
    unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'tr_product/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'config.json' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'CHANGELOG.md' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/system.prop' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_blur.sh' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_120hz.sh' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_sounds.sh' -d "$MODPATH" >&2
    unzip -oj "$ZIPFILE" 'common/apply_unlock.sh' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'apm_120hz_bypass/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'magellan/*' -d "$MODPATH" >&2
    unzip -o "$ZIPFILE" 'system/product/apm/*' -d "$MODPATH" >&2
  fi

  # Drop failed charging-animation / boot-sound packs. Keep custom UI sounds.
  rm -rf "$MODPATH/system/product/theme/charge" \
         "$MODPATH/tr_product/theme/charge" \
         "$MODPATH/product/theme/charge" \
         "$MODPATH/.charge_tr" "$MODPATH/.charge_prod"
  rm -f "$MODPATH/.charge_pick.mp4" "$MODPATH/charge_custom.mp4"
  rm -rf "$MODPATH/system/product/media/audio/bootsound" \
         "$MODPATH/tr_product/media/audio/bootsound" \
         "$MODPATH/product/media/audio/bootsound"
  rm -rf /mnt/vendor/mountify/tr_product/theme/charge \
         /mnt/vendor/mountify/product/theme/charge \
         /mnt/vendor/mountify/tr_product/media/audio/bootsound
  rm -f /data/local/bootaudio.mp3 /data/local/shutaudio.mp3
  ui_ok "Removed unused charging-animation and boot-sound files"

  OLD16=/data/adb/modules/transsion-flagship-16
  if [ -d "$OLD16/system/product/media/audio/ui" ]; then
    mkdir -p "$MODPATH/system/product/media/audio/ui"
    cp -a "$OLD16/system/product/media/audio/ui/"*_custom.* "$MODPATH/system/product/media/audio/ui/" 2>/dev/null
    ui_ok "Kept uploaded UI sounds"
  fi

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

  # V1.91 dropped the bundled emoji font (~34MB). Strip leftovers from older builds.
  rm -rf "$MODPATH/system/fonts" \
         /mnt/vendor/mountify/system/fonts/NotoColorEmoji.ttf \
         /mnt/vendor/mountify/system/fonts/NotoColorEmoji_custom.ttf
  rm -f "$MODPATH/apply_emoji.sh" "$MODPATH/emoji_custom.ttf"
  ui_ok "Removed emoji font (testing build — smaller zip)"

  CFG=/data/adb/modules/transsion-flagship-16/config.json
  if [ -f "$CFG" ]; then
    ui_ok "Existing Flagship 16 config preserved"
    cp "$CFG" "$MODPATH/config.json"
    # Undo V1.24 gallery/video-off, V1.25 eraser-only, and stock-off call summary.
    sed -i -e 's/"statusbar_style": *"ios"/"statusbar_style": "off"/' \
           -e 's/"statusbar_style": *"xos16"/"statusbar_style": "off"/' \
           -e 's/"ai_notif_summary"/"ai_writing"/' \
           -e 's/"ai_gallery": false/"ai_gallery": true/' \
           -e 's/"ai_video": false/"ai_video": true/' \
           -e 's/"ai_call_summary": false/"ai_call_summary": true/' \
           "$MODPATH/config.json"
  else
    ui_ok "Default config: HiOS 16 boot + reboot, AI + gaming + anim/blur on, dynamic bar off, status bar stock"
  fi
  # One-time: dynamic bar was default-on through V1.72. Force off once, then
  # leave later user toggles alone.
  if [ -f /data/adb/modules/transsion-flagship-16/.dynbar_off_v173 ]; then
    cp /data/adb/modules/transsion-flagship-16/.dynbar_off_v173 "$MODPATH/.dynbar_off_v173"
  else
    if grep -q '"dynamicbar_os16"' "$MODPATH/config.json" 2>/dev/null; then
      sed -i 's/"dynamicbar_os16":[[:space:]]*true/"dynamicbar_os16": false/' "$MODPATH/config.json"
    fi
    : > "$MODPATH/.dynbar_off_v173"
    ui_info "Dynamic bar default is now off (one-time)"
  fi
  if [ -f /data/adb/modules/transsion-flagship-16/.force_120hz ]; then
    cp /data/adb/modules/transsion-flagship-16/.force_120hz "$MODPATH/.force_120hz"
  fi
  # One-time: Pixel UI sounds become the default except keypress. Keep Custom.
  if [ -f /data/adb/modules/transsion-flagship-16/.pixel_sounds_v179 ]; then
    cp /data/adb/modules/transsion-flagship-16/.pixel_sounds_v179 "$MODPATH/.pixel_sounds_v179"
  else
    CFGJSON="$MODPATH/config.json"
    if [ -f "$CFGJSON" ]; then
      for k in chargesound wirelesschargesound sound_Unlock sound_Lock sound_Screenshots sound_Effect_Tick sound_LowBattery sound_InCallNotification sound_Dock sound_Undock; do
        if grep -q "\"${k}_style\"[[:space:]]*:[[:space:]]*\"custom\"" "$CFGJSON"; then
          continue
        fi
        if grep -q "\"${k}_style\"" "$CFGJSON"; then
          sed -i "s/\"${k}_style\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"${k}_style\": \"pixel\"/" "$CFGJSON"
        fi
      done
    fi
    : > "$MODPATH/.pixel_sounds_v179"
    ui_info "Pixel sounds are now the default except keypress (one-time)"
  fi
  write_os16_ai_prop "$MODPATH/config.json" "$MODPATH/system.prop"
  ui_ok "OS 16 keys written from config (reboot to apply)"

  if [ ! -f "$MODPATH/.dynbar_fix_v186" ]; then
    if ! grep -q '"dynamicbar_os16"[[:space:]]*:[[:space:]]*true' "$MODPATH/config.json" 2>/dev/null; then
      if [ -f "$MODPATH/apply_blur.sh" ]; then
        MODDIR="$MODPATH"
        CFG="$MODPATH/config.json"
        export MODDIR CFG
        . "$MODPATH/apply_blur.sh"
        os16_strip_dynamicbar_systemprop
      fi
      write_os16_ai_prop "$MODPATH/config.json" "$MODPATH/system.prop"
      ui_info "Stripped dynamicbar=0 from system.prop (stock bar restored on reboot)"
    fi
    : > "$MODPATH/.dynbar_fix_v186"
  fi

  ui_ok "Boot animation"
  ui_ok "Reboot animation"
  ui_ok "Status bar: upload your own overlay, or leave stock"
  ui_ok "Sounds: Pixel default (not keypress); charging Huawei / iOS / S25"
}

set_permissions() {
  # Magisk copies zip system.prop after on_install. Rewrite from config so
  # WebUI toggles survive an upgrade.
  write_os16_ai_prop "$MODPATH/config.json" "$MODPATH/system.prop"
  # TranOS 16 custom refresh is only Magellan XML in system/tr_product.
  # Copy that XML here when Force 120Hz is on so Mountify overlays it.
  if [ -f "$MODPATH/apply_120hz.sh" ]; then
    MODDIR="$MODPATH"
    CFG="$MODPATH/config.json"
    export MODDIR CFG
    . "$MODPATH/apply_120hz.sh"
    if os16_hz_on; then
      os16_generate_120hz_jsons
      os16_copy_magellan_mountify
    else
      os16_copy_magellan_mountify
    fi
  fi
  touch "$MODPATH/skip_mount"
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  for sh in "$MODPATH/post-fs-data.sh" "$MODPATH/service.sh" "$MODPATH/uninstall.sh" "$MODPATH/apply_blur.sh" "$MODPATH/apply_120hz.sh" "$MODPATH/apply_sounds.sh" "$MODPATH/apply_unlock.sh"; do
    [ -f "$sh" ] && set_perm "$sh" 0 0 0755
  done
  ui_print " "
  ui_div
  ui_print "  ✨  FLAGSHIP 16  ·  V1.87"
  ui_info "OS     : $OS_TYPE $OS_VER"
  ui_info "Feature: boot + reboot + overlay + AI + gaming + anim/blur + AOD + Dynamic bar + Force 120Hz + UI sounds"
  ui_div
  ui_print "  Reboot, then open WebUI in Magisk/KSU."
  ui_print " "
}
