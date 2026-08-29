#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/apply.sh"
: > "$MODDIR/lab.log"
lab_apply_early
