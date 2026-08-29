#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/apply.sh"
# Late pass: settings + device_config + re-bind after Mountify.
(
  sleep 8
  . "$MODDIR/apply.sh"
  lab_apply_late
) &
