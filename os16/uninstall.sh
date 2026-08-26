#!/system/bin/sh
LOG=/data/adb/transflagship16_uninstall.log
log_msg() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }
log_msg "=== TransFlagship 16 V1.02 uninstall start ==="
rm -f /data/adb/transflagship16_service.log
log_msg "=== TransFlagship 16 V1.02 uninstall complete — reboot ==="
