#!/system/bin/sh

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"

. "$MODDIR/apply_blur.sh"

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
  os16_rp_overwrite ro.tr_social.turbo_mode.support "$smode"
  os16_rp_overwrite ro.tr_social.record.support "$srec"
  os16_rp_overwrite ro.tr_social.call_translator.support "$strans"
  os16_rp_overwrite ro.tr_social.call_summary.support "$strans"
  os16_rp_overwrite ro.tr_social.sound_change.support "$srec"
  os16_rp_overwrite ro.tr_socialturbo.makeup.support "$sbeau"
  os16_rp_overwrite ro.tr_social.beauty_disable.support "$sbeau_dis"
  os16_rp_overwrite ro.tr_social.default_off.support "$sdefoff"
}

os16_apply_display_props() {
  hdr=$(os16_cfg_01 display_hdr true)
  col=$(os16_cfg_01 display_color true)
  os16_rp_overwrite ro.tr_display.sdr2hdr.support "$hdr"
  os16_rp_overwrite ro.tr_light.xdr.support "$hdr"
  os16_rp_overwrite ro.tr_light.xdr.v2.support "$hdr"
  os16_rp_overwrite ro.tr_display.colormode.feature.support "$col"
  os16_rp_overwrite ro.tr_display.color.temperature.feature.support "$col"
  os16_rp persist.tr_display.color.temperature.aosp.support "$col"
  os16_rp_overwrite ro.tran.display_hdr_support "$hdr"
  dc=$(os16_cfg_01 display_dc true)
  os16_rp_overwrite ro.tran.display_dc_dimming_support "$dc"
  if [ "$hdr" = "1" ]; then
    os16_rp_overwrite ro.surface_flinger.has_HDR_display true
  else
    os16_rp_overwrite ro.surface_flinger.has_HDR_display false
  fi
}

os16_apply_display_settings() {
  dc=$(os16_cfg_01 display_dc true)
  col=$(os16_cfg_01 display_color true)
  hdr=$(os16_cfg_01 display_hdr true)
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

os16_apply_settings_vconfig() {
  on=$(os16_cfg_bool scale_os16 true)
  if [ "$on" = "true" ] || [ "$on" = "1" ]; then val=true; else val=false; fi
  staged=$(os16_seed_vconfig_pkg com.android.settings)
  os16_vconfig_upsert "$staged" "tr_display.resolution.scalingup.support" "$val"
  os16_bind_vconfig_pkg "$staged" com.android.settings
  os16_rp_overwrite tr_display.resolution.scalingup.support "$val"
  os16_rp_overwrite ro.tr_display.resolution.scalingup.support "$val"
}

os16_apply_gt_apps_vconfig() {
  on=$(os16_cfg_bool gt_apps_os16 true)
  [ "$on" = "true" ] || [ "$on" = "1" ] || return 0
  os16_vconfig_pkg_keys com.gallery20 \
    tr_gallery.3dphoto.support 1 \
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
    tr_pcconnect.extend_screen.feature.support true \
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
}

os16_apply_circle_props() {
  c=$(os16_cfg_01 circle_os16 true)
  os16_rp_overwrite ro.tr_microIntelligence.circle_to_search.feature.support "$c"
  os16_rp_overwrite tr_microIntelligence.circle_to_search.feature.support "$c"
  os16_rp_overwrite ro.os_ai_circle_to_search_support "$c"
}

os16_apply_motion_sick_props() {
  c=$(os16_cfg_01 motion_sick_os16 true)
  os16_rp_overwrite ro.tr_microIntelligence.motion_sickness.feature.support "$c"
  os16_rp_overwrite tr_microIntelligence.motion_sickness.feature.support "$c"
}

os16_apply_unlock() {
  os16_apply_social_props
  os16_apply_display_props
  os16_apply_display_settings
  os16_apply_settings_vconfig
  os16_apply_gt_apps_vconfig
  os16_apply_circle_props
  os16_apply_motion_sick_props
}

if [ "${0##*/}" = "apply_unlock.sh" ]; then
  os16_apply_unlock
fi
