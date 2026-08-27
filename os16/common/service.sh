#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/transflagship16_service.log"
rm -f "$LOG"
log_p() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

cfg_bool() {
  k="$1"; d="$2"
  [ -f "$MODDIR/config.json" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$MODDIR/config.json" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

cfg_int() {
  k="$1"; d="$2"
  v=$(cfg_bool "$k" "$d")
  case "$v" in
    ''|*[!0-9]*) echo "$d" ;;
    *) echo "$v" ;;
  esac
}

apply_blur_runtime() {
  on=$(cfg_bool blur_os16 true)
  lvl=$(cfg_int blur_os16_level 2)
  [ "$lvl" -ge 1 ] 2>/dev/null || lvl=2
  [ "$lvl" -le 3 ] 2>/dev/null || lvl=2
  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    dis=0
    en=1
    case "$lvl" in
      1) rad=20 ;;
      3) rad=80 ;;
      *) rad=45 ;;
    esac
  else
    dis=1
    en=0
    rad=0
  fi
  settings put global disable_window_blurs "$dis" 2>/dev/null
  settings put system transsion_launcher_gaussian_blur_enable "$en" 2>/dev/null
  settings put system transsion_launcher_blur_radius "$rad" 2>/dev/null
  wm disable-blur "$dis" 2>/dev/null
  cmd window disable-blur "$dis" 2>/dev/null
  am force-stop com.transsion.launcher3 2>/dev/null
  log_p "  blur_runtime on=$on lvl=$lvl disable_window_blurs=$dis radius=$rad"
}

log_p "=== TransFlagship 16 V1.33 ==="
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
log_p "  liquidglass=$(getprop ro.tr_display.liquidglass.support 2>/dev/null)"
log_p "  sf_blur=$(getprop ro.surface_flinger.supports_background_blur 2>/dev/null)"
log_p "  recent_blur=$(getprop ro.os.recent.blur 2>/dev/null)"
log_p "  gaussian=$(getprop ro.transsion_launcher_gaussian_blur_support 2>/dev/null)"
log_p "  sf_disable_blurs=$(getprop persist.sys.sf.disable_blurs 2>/dev/null)"
apply_blur_runtime
log_p "=== service complete ==="
