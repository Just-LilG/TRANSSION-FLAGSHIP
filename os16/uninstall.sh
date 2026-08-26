#!/system/bin/sh
LOG=/data/adb/transflagship16_uninstall.log
log_msg() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }
log_msg "=== TransFlagship 16 V1.22 uninstall start ==="
rm -f /data/adb/transflagship16_service.log
rm -f /data/local/bootaudio.mp3 /data/local/shutaudio.mp3
rm -rf /mnt/vendor/mountify/tr_product/theme/charge
rm -rf /mnt/vendor/mountify/product/theme/charge
rm -rf /mnt/vendor/mountify/tr_product/media/audio/bootsound
log_msg "=== TransFlagship 16 V1.22 uninstall complete — reboot ==="
