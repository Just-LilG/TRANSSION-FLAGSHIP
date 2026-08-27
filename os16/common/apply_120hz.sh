#!/system/bin/sh
# Flagship 16 Force 120Hz. Same Transsion settings as Flagship 15 on X6886.
# Off does not write a fake 60Hz default. Per-app APM json is bind-mounted
# over a live dest only (not bind-dir). Do not resetprop AI keys here.

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"

os16_cfg_bool() {
  k="$1"; d="$2"
  [ -f "$CFG" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

os16_apply_120hz_settings() {
  on=$(os16_cfg_bool force_120hz false)
  if [ "$on" != "true" ] && [ "$on" != "1" ]; then
    return 0
  fi
  settings put system tran_refresh_mode 120 >/dev/null 2>&1
  settings put system tran_need_recovery_refresh_mode 120 >/dev/null 2>&1
  settings put system tran_need_recovery_refresh_rate 120 >/dev/null 2>&1
  settings put system last_tran_refresh_mode_in_refresh_setting 120 >/dev/null 2>&1
  settings put system peak_refresh_rate 120.0 >/dev/null 2>&1
  settings put system min_refresh_rate 120.0 >/dev/null 2>&1
}

if [ "${0##*/}" = "apply_120hz.sh" ]; then
  os16_apply_120hz_settings
fi
