#!/system/bin/sh
LOG=/data/adb/transflagship16_uninstall.log
log_msg() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }
log_msg "=== TransFlagship 16 V1.32 uninstall start ==="
rm -f /data/adb/transflagship16_service.log
rm -f /data/local/bootaudio.mp3 /data/local/shutaudio.mp3
rm -rf /mnt/vendor/mountify/tr_product/theme/charge
rm -rf /mnt/vendor/mountify/product/theme/charge
rm -rf /mnt/vendor/mountify/tr_product/media/audio/bootsound
settings delete system transsion_launcher_gaussian_blur_enable 2>/dev/null
log_msg "=== TransFlagship 16 V1.32 uninstall complete — reboot ==="
