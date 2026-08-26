#!/system/bin/sh

LOG=/data/adb/transflagship_uninstall.log
log_msg() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log_msg "=== TransFlagship V4.22 uninstall start ==="

settings put global window_animation_scale 1.0
settings put global transition_animation_scale 1.0
settings put global animator_duration_scale 1.0
log_msg "Animation scales restored"

settings delete system transsion_launcher_gaussian_blur_enable
settings delete system transsion_launcher_blur_radius
log_msg "Launcher blur removed"

settings delete system tran_dc_dimming_enable
settings delete system tran_display_color_enhance
settings delete system tran_reading_mode_enable
log_msg "Display settings removed"

settings delete system tran_refresh_mode
settings delete system tran_need_recovery_refresh_mode
settings delete system tran_need_recovery_refresh_rate
settings delete system last_tran_refresh_mode_in_refresh_setting
settings delete system peak_refresh_rate
settings delete system min_refresh_rate
log_msg "Refresh-rate overrides removed"

settings delete global disable_secure_windows
settings delete system screenshot_capture_disabled
settings delete global sysui_demo_allowed
log_msg "Screenshot settings restored"

rm -f /data/adb/transflagship_service.log
log_msg "Service log cleaned"

log_msg "=== TransFlagship V4.22 uninstall complete — reboot to fully restore ==="
