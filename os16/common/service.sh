#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_p "=== TransFlagship 16 V1.86 ==="
log_p "Device : $(getprop ro.product.model 2>/dev/null)"
log_p "Brand  : $(getprop ro.product.brand 2>/dev/null)"
log_p "Android: $(getprop ro.build.version.release 2>/dev/null)"
log_p "ro.tran.os.type : $(getprop ro.tran.os.type 2>/dev/null)"
log_p "ro.transsion.os.version: $(getprop ro.transsion.os.version 2>/dev/null)"
log_p "tr_product: $([ -d /tr_product ] && echo yes || echo no)"
if [ -f "$MODDIR/install_diagnostic.txt" ]; then
    while IFS= read -r line; do log_p "$line"; done < "$MODDIR/install_diagnostic.txt"
fi
log_p "config: $([ -f "$MODDIR/config.json" ] && cat "$MODDIR/config.json" || echo missing)"

if [ -f "$MODDIR/apply_blur.sh" ]; then
  . "$MODDIR/apply_blur.sh"
  OS16_BOOT=1
  export OS16_BOOT
  os16_apply_blur_props
  os16_apply_aod_props
  os16_apply_os16_extras_props
  os16_apply_dynamicbar_props
  os16_clear_failed_feature_leftovers
  os16_apply_aod_settings
  os16_apply_dynamicbar_runtime
  if [ -f "$MODDIR/apply_unlock.sh" ]; then
    . "$MODDIR/apply_unlock.sh"
    os16_apply_unlock
  fi
  os16_apply_blur_runtime
  # Do not restart SurfaceFlinger or force-stop home/AOD here. That is the
  # post-boot soft reboot.
  log_p "blur apply: anim=$(os16_cfg_bool anim_os16 true) on=$(os16_cfg_bool blur_os16 true) lvl=$(os16_cfg_int blur_os16_level 2) platform=$(getprop ro.tr_animation.platform_level 2>/dev/null) union=$(getprop ro.tran_display_unionrender.support 2>/dev/null) liquidglass=$(getprop ro.tr_display.liquidglass.support 2>/dev/null)"
  log_p "aod apply: on=$(os16_cfg_bool aod_os16 true) feature=$(getprop ro.tr_aod.feature.support 2>/dev/null) always_show=$(getprop tr_aod.always.show.feature.support 2>/dev/null) vconfig=$(grep always.show /tr_product/etc/vconfig/com.transsion.aod/build.prop 2>/dev/null) doze_always=$(settings get secure doze_always_on 2>/dev/null)"
  log_p "extras apply: videosr=$(getprop persist.tr_video.ai_super_resolution.support 2>/dev/null) supervol=$(getprop ro.tr_audio.supervol.feature.support 2>/dev/null) treasure=$(getprop ro.tr_ai_treasure_box.feature.support 2>/dev/null) cutepet=$(getprop ro.tr_cutepet.feature.support 2>/dev/null) outdoor=$(getprop ro.tr_outdoorboost.feature.support 2>/dev/null) gallerylive=$(getprop tr_gallery.live.support 2>/dev/null) airtransfer=$(getprop ro.tr_airtransfer.feature.support 2>/dev/null)"
  log_p "dynamicbar apply: on=$(os16_cfg_bool dynamicbar_os16 false) bar=$(getprop ro.tr_dynamicbar.support 2>/dev/null) translate=$(getprop ro.os_dynamicbar_ai_translation_support 2>/dev/null) plane=$(getprop ro.os_dynamic_bar_resident_plane_support 2>/dev/null) hide_land=$(getprop ro.os.tran_hide_status_bar_for_land_recent 2>/dev/null) hios=$(getprop ro.tran_hios_dynamic_bar_support 2>/dev/null)"
else
  log_p "apply_blur.sh missing"
fi

if [ -f "$MODDIR/apply_120hz.sh" ]; then
  . "$MODDIR/apply_120hz.sh"
  os16_apply_game_fps_props
  os16_apply_120hz_settings
  log_p "force_120hz=$(os16_cfg_bool force_120hz false) peak=$(settings get system peak_refresh_rate 2>/dev/null) game_fps=$(getprop ro.surface_flinger.game_default_frame_rate_override 2>/dev/null) magellan=$(ls /tr_product/etc/vconfig/magellan/refresh_rate_config.xml 2>/dev/null && echo yes || echo missing) max144=$(grep -c 'max=\"144\"' /tr_product/etc/vconfig/magellan/refresh_rate_config.xml 2>/dev/null)"
else
  log_p "apply_120hz.sh missing"
fi

if [ -f "$MODDIR/apply_sounds.sh" ]; then
  . "$MODDIR/apply_sounds.sh"
  os16_apply_sounds
  log_p "ui sounds charge=$(ls -l /tr_product/media/audio/ui/ChargingStarted.ogg 2>/dev/null | awk '{print $5,$NF}') unlock=$(ls -l /tr_product/media/audio/ui/Unlock.ogg 2>/dev/null | awk '{print $5,$NF}')"
else
  log_p "apply_sounds.sh missing"
fi

if [ -f "$MODDIR/apply_emoji.sh" ]; then
  . "$MODDIR/apply_emoji.sh"
  os16_apply_emoji
  log_p "emoji live=$(ls -l /system/fonts/NotoColorEmoji.ttf 2>/dev/null | awk '{print $5,$NF}')"
else
  log_p "apply_emoji.sh missing"
fi

log_p "OS 16 AI keys (read only):"
log_p "  subtitle=$(getprop ro.tr_aiservice.aicorespeech_subtitle.feature.support 2>/dev/null)"
log_p "  livecaption=$(getprop ro.tr_aiservice.aicorespeech_livecaption.feature.support 2>/dev/null)"
log_p "  recorder=$(getprop ro.tr_soundrecorder.summary.feature.support 2>/dev/null)"
log_p "  notes_draw=$(getprop ro.tr_note.ai_draw.support 2>/dev/null)"
log_p "  writing=$(getprop ro.os_ai_writing.support 2>/dev/null)"
log_p "  aiphone=$(getprop ro.tr_aiassistant.aiphone.feature.support 2>/dev/null)"
log_p "  aiphone_summany=$(getprop ro.tr_aiassistant.aiphone_summany.feature.support 2>/dev/null)"
log_p "  gallery_art=$(getprop ro.tr_gallery.ai_art.support 2>/dev/null)"
log_p "  gallery_studio=$(getprop ro.tr_gallery.ai.studio.lite.support 2>/dev/null)"
log_p "  gallery_eraser=$(getprop ro.tr_gallery.eraser.v2.support 2>/dev/null)"
  log_p "  video_vee=$(getprop ro.tr_video.vee.support 2>/dev/null)"
  log_p "  game_esport=$(getprop ro.tr_game.e_sport_mode.support 2>/dev/null)"
log_p "  esports10=$(getprop ro.tr_game.tp_esports10.feature.support 2>/dev/null)"
log_p "  bypass=$(getprop ro.tr_game.bypass_charging.support 2>/dev/null)"
log_p "  shoulder=$(getprop ro.tr_game.shoulder_key.support 2>/dev/null)"
log_p "  pic_trig=$(getprop ro.tr_game.ai_picture_triggers.support 2>/dev/null)"
log_p "  shoulderbtn=$(getprop ro.tr_smartbutton.shoulderbutton20.feature.support 2>/dev/null)"
log_p "  anim_level=$(getprop ro.tr_animation.platform_level 2>/dev/null)"
log_p "  launch_model=$(getprop ro.tr_perf.launch_start_exit.model 2>/dev/null)"
log_p "  recent_model=$(getprop ro.tr_perf.recent_animation.model 2>/dev/null)"
log_p "  async_anim=$(getprop ro.transsion_async_animation_support 2>/dev/null)"
log_p "  aod=$(getprop ro.tr_aod.feature.support 2>/dev/null)"
log_p "  aod_half=$(getprop ro.tr_aod.half.screen.feature.support 2>/dev/null)"
log_p "  aod_always=$(getprop ro.aod_alwaysshow_support 2>/dev/null)"
log_p "  aod_v3=$(getprop ro.tran_aod_v3_support 2>/dev/null)"
log_p "  dynamicbar=$(getprop ro.tr_dynamicbar.support 2>/dev/null)"
log_p "  dynamicbar_translate=$(getprop ro.os_dynamicbar_ai_translation_support 2>/dev/null)"
log_p "  liquidglass=$(getprop ro.tr_display.liquidglass.support 2>/dev/null)"
log_p "  sf_blur=$(getprop ro.surface_flinger.supports_background_blur 2>/dev/null)"
log_p "  recent_blur=$(getprop ro.os.recent.blur 2>/dev/null)"
log_p "  gaussian=$(getprop ro.transsion_launcher_gaussian_blur_support 2>/dev/null)"
log_p "  sf_disable_blurs=$(getprop persist.sys.sf.disable_blurs 2>/dev/null)"
log_p "  sysui_disableBlur=$(getprop persist.sysui.disableBlur 2>/dev/null)"
log_p "  home=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1)"

# Mountify / tr_product overlay can rewrite liquidglass after post-fs-data.
# Re-apply props once boot has settled. Do not kill SurfaceFlinger or home.
(
  sleep 8
  [ -f "$MODDIR/apply_blur.sh" ] || exit 0
  . "$MODDIR/apply_blur.sh"
  OS16_BOOT=1
  export OS16_BOOT
  os16_apply_blur_props
  os16_apply_aod_props
  os16_apply_os16_extras_props
  os16_apply_dynamicbar_props
  os16_apply_aod_settings
  os16_apply_dynamicbar_runtime
  if [ -f "$MODDIR/apply_unlock.sh" ]; then
    . "$MODDIR/apply_unlock.sh"
    os16_apply_unlock
  fi
    echo "[$(date '+%H:%M:%S')] blur props after settle liquidglass=$(getprop ro.tr_display.liquidglass.support 2>/dev/null) aod_always=$(getprop ro.aod_alwaysshow_support 2>/dev/null) bar=$(getprop ro.tr_dynamicbar.support 2>/dev/null) plane=$(getprop ro.os_dynamic_bar_resident_plane_support 2>/dev/null)" >> "$LOG"
  if [ -f "$MODDIR/apply_120hz.sh" ]; then
    . "$MODDIR/apply_120hz.sh"
    os16_apply_game_fps_props
    os16_apply_120hz_settings
    echo "[$(date '+%H:%M:%S')] refresh after settle force=$(os16_cfg_bool force_120hz false) magellan=$(ls /tr_product/etc/vconfig/magellan/refresh_rate_config.xml 2>/dev/null && echo yes || echo missing) max144=$(grep -c 'max=\"144\"' /tr_product/etc/vconfig/magellan/refresh_rate_config.xml 2>/dev/null)" >> "$LOG"
  fi
  if [ -f "$MODDIR/apply_sounds.sh" ]; then
    . "$MODDIR/apply_sounds.sh"
    os16_apply_sounds
    echo "[$(date '+%H:%M:%S')] ui sounds after settle charge=$(ls -l /tr_product/media/audio/ui/ChargingStarted.ogg 2>/dev/null | awk '{print $5}') unlock=$(ls -l /tr_product/media/audio/ui/Unlock.ogg 2>/dev/null | awk '{print $5}')" >> "$LOG"
  fi
  if [ -f "$MODDIR/apply_emoji.sh" ]; then
    . "$MODDIR/apply_emoji.sh"
    os16_apply_emoji
    echo "[$(date '+%H:%M:%S')] emoji after settle live=$(ls -l /system/fonts/NotoColorEmoji.ttf 2>/dev/null | awk '{print $5}')" >> "$LOG"
  fi
) &

log_p "=== service complete ==="
