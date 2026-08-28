#!/system/bin/sh
LOG=/data/adb/transflagship16_uninstall.log
log_msg() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }
MODDIR=/data/adb/modules/transsion-flagship-16
log_msg "=== TransFlagship 16 V1.85 uninstall start ==="
if [ -f "$MODDIR/apply_sounds.sh" ]; then
  . "$MODDIR/apply_sounds.sh"
  os16_umount_sounds
  log_msg "ui sound binds unmounted"
fi
if [ -f "$MODDIR/apply_emoji.sh" ]; then
  . "$MODDIR/apply_emoji.sh"
  os16_umount_emoji
  log_msg "emoji font binds unmounted"
fi
rm -f /data/adb/transflagship16_service.log
rm -f /data/local/bootaudio.mp3 /data/local/shutaudio.mp3
rm -rf /mnt/vendor/mountify/tr_product/theme/charge
rm -rf /mnt/vendor/mountify/product/theme/charge
rm -rf /mnt/vendor/mountify/tr_product/media/audio/bootsound
settings delete system transsion_launcher_gaussian_blur_enable 2>/dev/null
settings delete global transsion_launcher_gaussian_blur_enable 2>/dev/null
settings delete system transsion_launcher_blur_radius 2>/dev/null
settings delete global transsion_launcher_blur_radius 2>/dev/null
settings delete system transsion_launcher_gaussian_blur_support 2>/dev/null
settings delete global transsion_launcher_gaussian_blur_support 2>/dev/null
settings delete system transsion_launcher_gaussian_support 2>/dev/null
settings delete global transsion_launcher_gaussian_support 2>/dev/null
settings delete system disable_window_blurs 2>/dev/null
settings delete global disable_window_blurs 2>/dev/null
settings delete system tran_dc_dimming_enable 2>/dev/null
settings delete global tran_dc_dimming_enable 2>/dev/null
settings delete system tran_display_color_enhance 2>/dev/null
settings delete global tran_display_color_enhance 2>/dev/null
settings delete system tran_reading_mode_enable 2>/dev/null
settings delete global tran_reading_mode_enable 2>/dev/null
settings delete system tr_dc_dimming_enable 2>/dev/null
settings delete global tr_dc_dimming_enable 2>/dev/null
settings delete system tr_display_color_enhance 2>/dev/null
settings delete global tr_display_color_enhance 2>/dev/null
settings delete system tr_reading_mode_enable 2>/dev/null
settings delete global tr_reading_mode_enable 2>/dev/null
settings delete system tran_sdr2hdr_enable 2>/dev/null
settings delete global tran_sdr2hdr_enable 2>/dev/null
settings delete secure doze_always_on 2>/dev/null
settings delete system doze_always_on 2>/dev/null
settings delete global doze_always_on 2>/dev/null
settings delete system tran_aod_enable 2>/dev/null
settings delete global tran_aod_enable 2>/dev/null
settings delete system tr_aod_enable 2>/dev/null
settings delete global tr_aod_enable 2>/dev/null
settings delete secure accessibility_reduce_transparency 2>/dev/null
for ns in system global; do
  settings delete "$ns" tran_refresh_mode 2>/dev/null
  settings delete "$ns" tran_need_recovery_refresh_mode 2>/dev/null
  settings delete "$ns" tran_need_recovery_refresh_rate 2>/dev/null
  settings delete "$ns" last_tran_refresh_mode_in_refresh_setting 2>/dev/null
  settings delete "$ns" tran_default_refresh_mode 2>/dev/null
  settings delete "$ns" peak_refresh_rate 2>/dev/null
  settings delete "$ns" min_refresh_rate 2>/dev/null
  settings delete "$ns" user_refresh_rate 2>/dev/null
  settings delete "$ns" preferred_refresh_rate 2>/dev/null
  settings delete "$ns" max_refresh_rate 2>/dev/null
  settings delete "$ns" min_frame_rate 2>/dev/null
  settings delete "$ns" max_frame_rate 2>/dev/null
  settings delete "$ns" other_apps_refresh_rate 2>/dev/null
  settings delete "$ns" default_app_refresh_rate 2>/dev/null
  settings delete "$ns" tran_other_app_refresh_rate 2>/dev/null
  settings delete "$ns" tran_app_refresh_rate 2>/dev/null
  settings delete "$ns" tran_custom_app_refresh_rate 2>/dev/null
  settings delete "$ns" app_refresh_rate_config 2>/dev/null
  settings delete "$ns" custom_app_refresh_rate 2>/dev/null
  settings delete "$ns" tran_refresh_rate_apps 2>/dev/null
done
settings delete secure user_refresh_rate 2>/dev/null
settings delete global tran_default_auto_refresh.support 2>/dev/null
settings delete global tran_90hz_refresh_rate.not_support 2>/dev/null
settings delete global tran_144hz_refresh_rate.support 2>/dev/null
settings delete global tran_low_battery_60hz_refresh_rate.support 2>/dev/null
settings delete global tran_custom_refresh_rate_config.support 2>/dev/null
resetprop --delete persist.sys.peak_refresh_rate 2>/dev/null
resetprop --delete persist.sys.min_refresh_rate 2>/dev/null
for pkg in com.android.settings com.transsion.ossettingsext com.transsion.trsettings; do
  for dir in /data/user_de/0/$pkg/shared_prefs /data/user/0/$pkg/shared_prefs /data/data/$pkg/shared_prefs; do
    rm -f "$dir/flagship16_app_refresh_rate.xml" \
          "$dir/app_refresh_rate.xml" \
          "$dir/tran_app_refresh_rate.xml" \
          "$dir/pref_app_refresh_rate.xml" \
          "$dir/custom_app_refresh_rate.xml" \
          "$dir/RefreshRate.xml"
  done
done
wm disable-blur 0 2>/dev/null
cmd window disable-blur 0 2>/dev/null
rm -f /data/adb/modules/transsion-flagship-16/system/tr_product/etc/vconfig/magellan/refresh_rate_config.xml 2>/dev/null
rm -f /data/magellan/refresh_rate_config.xml 2>/dev/null
rm -f /mnt/vendor/mountify/tr_product/etc/vconfig/magellan/refresh_rate_config.xml 2>/dev/null
log_msg "=== TransFlagship 16 V1.84 uninstall complete — reboot ==="
