#!/system/bin/sh
# Flagship 16 refresh: default 120 or 144 for every installed package.
# The Customize App Refresh list reads Settings prefs / per-app keys, not
# the APM whitelist. V1.40 only wrote APM + global mode, so the list stayed
# at 90Hz. Off does not write a fake 60Hz default.

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"
HZDIR="$MODDIR/apm_120hz_bypass"

os16_cfg_bool() {
  k="$1"; d="$2"
  [ -f "$CFG" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

os16_cfg_int() {
  k="$1"; d="$2"
  v=$(os16_cfg_bool "$k" "$d")
  case "$v" in
    ''|*[!0-9]*) echo "$d" ;;
    *) echo "$v" ;;
  esac
}

os16_hz_target() {
  v=$(os16_cfg_int force_refresh_hz 0)
  case "$v" in
    120|144) echo "$v"; return ;;
  esac
  on=$(os16_cfg_bool force_120hz false)
  if [ "$on" = "true" ] || [ "$on" = "1" ]; then
    echo 120
    return
  fi
  echo 0
}

os16_hz_on() {
  t=$(os16_hz_target)
  [ "$t" = "120" ] || [ "$t" = "144" ]
}

os16_hz_rp() {
  k="$1"; v="$2"
  if [ -x /data/adb/magisk/resetprop ]; then
    /data/adb/magisk/resetprop --delete "$k" >/dev/null 2>&1
  fi
  if command -v resetprop >/dev/null 2>&1; then
    resetprop --delete "$k" >/dev/null 2>&1
  fi
  if [ -x /data/adb/ksud ]; then
    /data/adb/ksud resetprop --delete "$k" >/dev/null 2>&1
  fi
  if [ -x /data/adb/ksud ]; then
    /data/adb/ksud resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if [ -x /data/adb/magisk/resetprop ]; then
    /data/adb/magisk/resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    /data/adb/magisk/resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  if command -v resetprop >/dev/null 2>&1; then
    resetprop -n "$k" "$v" >/dev/null 2>&1 && return 0
    resetprop "$k" "$v" >/dev/null 2>&1 && return 0
  fi
  setprop "$k" "$v" >/dev/null 2>&1
}

os16_120hz_nsenter() {
  if [ -x /system/bin/nsenter ]; then
    echo "/system/bin/nsenter -t 1 -m --"
  elif command -v nsenter >/dev/null 2>&1; then
    echo "nsenter -t 1 -m --"
  fi
}

os16_120hz_umount() {
  dest="$1"
  NS=$(os16_120hz_nsenter)
  [ -n "$NS" ] && $NS umount -l "$dest" 2>/dev/null
  umount -l "$dest" 2>/dev/null
}

os16_120hz_bind_file() {
  src="$1"
  dest="$2"
  [ -f "$src" ] || return 1
  [ -e "$dest" ] || return 1
  chcon --reference="$dest" "$src" 2>/dev/null
  chmod 644 "$src" 2>/dev/null
  NS=$(os16_120hz_nsenter)
  if [ -n "$NS" ]; then
    $NS umount -l "$dest" 2>/dev/null
    if $NS mount --bind "$src" "$dest"; then
      return 0
    fi
  fi
  umount -l "$dest" 2>/dev/null
  mount --bind "$src" "$dest"
}

os16_120hz_dests() {
  name="$1"
  echo "/product/apm/config/$name"
  echo "/system/product/apm/config/$name"
  echo "/tr_product/etc/apm/config/$name"
  echo "/tr_product/apm/config/$name"
  for root in /tr_product /product /system /system_ext /vendor /odm /oem /custom; do
    [ -d "$root" ] || continue
    find "$root" -maxdepth 6 -name "$name" 2>/dev/null
  done
}

os16_bind_120hz_files() {
  for name in refresh_rate_config.json project_refresh_rate_config.json; do
    src="$HZDIR/$name"
    os16_120hz_dests "$name" | awk 'NF && !seen[$0]++' | while IFS= read -r dest; do
      os16_120hz_umount "$dest"
      if os16_hz_on; then
        os16_120hz_bind_file "$src" "$dest"
      fi
    done
  done
}

os16_write_pkg_array() {
  tmp="$HZDIR/.pkgs.txt"
  {
    echo android
    echo com.android.systemui
    pm list packages 2>/dev/null | sed 's/^package://'
    pm list packages -s 2>/dev/null | sed 's/^package://'
    pm list packages -3 2>/dev/null | sed 's/^package://'
    pm list packages -a 2>/dev/null | sed 's/^package://'
  } 2>/dev/null | tr -d '\r' | grep -E '^[A-Za-z0-9._]+$' | sort -u > "$tmp"
  n=$(wc -l < "$tmp" 2>/dev/null | tr -d ' ')
  [ -z "$n" ] && n=0
  echo "$n" > "$HZDIR/.pkg_count"
  awk '
    BEGIN { print "[" }
    NF {
      if (n++) printf ",\n"
      printf "    \"%s\"", $0
    }
    END { print "\n  ]" }
  ' "$tmp"
}

os16_json_replace_top_array() {
  json="$1"
  key="$2"
  arrf="$3"
  [ -f "$json" ] && [ -f "$arrf" ] || return 1
  awk -v key="$key" -v arrf="$arrf" '
    function loadarr(    l) {
      arrbody = ""
      while ((getline l < arrf) > 0) {
        if (arrbody != "") arrbody = arrbody "\n"
        arrbody = arrbody l
      }
      close(arrf)
    }
    BEGIN {
      loadarr()
      look = "\"" key "\""
    }
    {
      if (skip) {
        if ($0 ~ /^  \],[[:space:]]*$/ || $0 ~ /^  \][[:space:]]*$/) {
          skip = 0
          comma = ($0 ~ /,$/) ? "," : ""
          print "  " look ": " arrbody comma
        }
        next
      }
      if (index($0, look) && $0 ~ /:[[:space:]]*\[/) {
        if ($0 ~ /\[[[:space:]]*\]/) {
          comma = ($0 ~ /,$/) ? "," : ""
          print "  " look ": " arrbody comma
          next
        }
        skip = 1
        next
      }
      print
    }
  ' "$json" > "$json.new" && mv "$json.new" "$json"
}

os16_generate_120hz_jsons() {
  os16_hz_on || return 0
  mkdir -p "$HZDIR"
  arr="$HZDIR/.all_pkgs.jsonarray"
  empty="$HZDIR/.empty.jsonarray"
  echo '[]' > "$empty"
  os16_write_pkg_array > "$arr"
  n=$(cat "$HZDIR/.pkg_count" 2>/dev/null)
  [ -z "$n" ] && n=0
  if [ "$n" -lt 8 ]; then
    echo "pm-not-ready:$n" > "$HZDIR/.pkg_count"
    return 0
  fi
  for json in "$HZDIR/refresh_rate_config.json" "$HZDIR/project_refresh_rate_config.json"; do
    [ -f "$json" ] || continue
    os16_json_replace_top_array "$json" auto_refresh_rate_whitelist "$arr"
    os16_json_replace_top_array "$json" slide_in_higher_setting_mode_120hz "$arr"
    os16_json_replace_top_array "$json" high_refresh_rate_gameList_in_120hz_mode "$arr"
    os16_json_replace_top_array "$json" limit_60hz_in_all_setting_mode "$empty"
    os16_json_replace_top_array "$json" limit_90hz_in_higher_setting_mode "$empty"
    os16_json_replace_top_array "$json" limit_120hz_in_auto_mode "$empty"
    os16_json_replace_top_array "$json" app_request_black_list "$empty"
    os16_json_replace_top_array "$json" fast_slow_slide_blacklist "$empty"
    os16_json_replace_top_array "$json" video_45hz_whitelist "$empty"
    os16_json_replace_top_array "$json" video_call_45hz_whitelist "$empty"
    os16_json_replace_top_array "$json" refresh_rate_90hz_whitelist_in_120hz_mode "$empty"
    os16_json_replace_top_array "$json" refresh_rate_blacklist_in_90hz_mode "$empty"
    os16_json_replace_top_array "$json" min_refresh_rate_90hz_in_auto_mode "$empty"
  done
}

os16_put_hz() {
  ns="$1"; key="$2"; val="$3"
  settings put "$ns" "$key" "$val" >/dev/null 2>&1
}

os16_pkg_uid() {
  pkg="$1"
  dumpsys package "$pkg" 2>/dev/null | grep -m1 'userId=' | sed 's/.*userId=\([0-9]*\).*/\1/'
}

os16_install_pref_xml() {
  xml="$1"
  pkg="$2"
  [ -f "$xml" ] || return 1
  uid=$(os16_pkg_uid "$pkg")
  [ -z "$uid" ] && uid=1000
  for dir in \
      /data/user_de/0/$pkg/shared_prefs \
      /data/user/0/$pkg/shared_prefs \
      /data/data/$pkg/shared_prefs
  do
    parent=$(dirname "$dir")
    [ -d "$parent" ] || continue
    mkdir -p "$dir" 2>/dev/null
    for name in flagship16_app_refresh_rate.xml app_refresh_rate.xml \
                tran_app_refresh_rate.xml pref_app_refresh_rate.xml \
                custom_app_refresh_rate.xml RefreshRate.xml; do
      cp -f "$xml" "$dir/$name" 2>/dev/null || continue
      chmod 660 "$dir/$name" 2>/dev/null
      chown "$uid:$uid" "$dir/$name" 2>/dev/null
      chcon u:object_r:app_data_file:s0 "$dir/$name" 2>/dev/null
    done
  done
}

os16_write_app_defaults() {
  hz=$(os16_hz_target)
  [ "$hz" = "120" ] || [ "$hz" = "144" ] || return 0
  pkgs="$HZDIR/.pkgs.txt"
  [ -s "$pkgs" ] || return 0

  xml="$HZDIR/flagship16_app_refresh_rate.xml"
  {
    echo "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>"
    echo '<map>'
    echo "  <int name=\"__default__\" value=\"$hz\" />"
    echo "  <int name=\"other_apps\" value=\"$hz\" />"
    echo "  <int name=\"default_refresh_rate\" value=\"$hz\" />"
    echo "  <int name=\"tran_default_refresh_rate\" value=\"$hz\" />"
    while IFS= read -r pkg; do
      [ -n "$pkg" ] || continue
      echo "  <int name=\"$pkg\" value=\"$hz\" />"
    done < "$pkgs"
    echo '</map>'
  } > "$xml"

  json="$HZDIR/flagship16_app_refresh_rate.json"
  awk -v hz="$hz" '
    BEGIN { printf "{" }
    NF {
      if (n++) printf ","
      printf "\"%s\":%s", $0, hz
    }
    END { print "}" }
  ' "$pkgs" > "$json"

  map="$HZDIR/flagship16_app_refresh_rate.map"
  awk -v hz="$hz" '
    NF {
      if (n++) printf ";"
      printf "%s:%s", $0, hz
    }
    END { print "" }
  ' "$pkgs" > "$map"
  blob=$(cat "$json" 2>/dev/null)
  mapblob=$(cat "$map" 2>/dev/null)

  for ns in system global secure; do
    os16_put_hz "$ns" tran_app_refresh_rate "$blob"
    os16_put_hz "$ns" tran_custom_app_refresh_rate "$blob"
    os16_put_hz "$ns" app_refresh_rate_config "$blob"
    os16_put_hz "$ns" custom_app_refresh_rate "$mapblob"
    os16_put_hz "$ns" tran_refresh_rate_apps "$mapblob"
    os16_put_hz "$ns" other_apps_refresh_rate "$hz"
    os16_put_hz "$ns" default_app_refresh_rate "$hz"
    os16_put_hz "$ns" tran_other_app_refresh_rate "$hz"
  done

  # Per-app keys the Customize list may store after a tap.
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    os16_put_hz system "tran_refresh_rate_$pkg" "$hz"
    os16_put_hz system "refresh_rate_$pkg" "$hz"
  done < "$pkgs"

  os16_install_pref_xml "$xml" com.android.settings
  os16_install_pref_xml "$xml" com.transsion.ossettingsext
  os16_install_pref_xml "$xml" com.transsion.trsettings
  am force-stop com.android.settings >/dev/null 2>&1
  am force-stop com.transsion.ossettingsext >/dev/null 2>&1
}

os16_apply_120hz_props() {
  hz=$(os16_hz_target)
  [ "$hz" = "120" ] || [ "$hz" = "144" ] || return 0
  os16_hz_rp ro.tran_90hz_refresh_rate.not_support 1
  os16_hz_rp ro.tr_display.90hz.not_support 1
  os16_hz_rp ro.tran_default_auto_refresh.support 0
  os16_hz_rp ro.tr_display.default_auto_refresh.support 0
  os16_hz_rp ro.tran_custom_refresh_rate_config.support 1
  os16_hz_rp persist.sys.peak_refresh_rate "$hz"
  os16_hz_rp persist.sys.min_refresh_rate "$hz"
  if [ "$hz" = "144" ]; then
    os16_hz_rp ro.tran_144hz_refresh_rate.support 1
    os16_hz_rp ro.tr_display.144hz.support 1
    os16_hz_rp ro.tran_144hz_refresh_rate.not_support 0
  else
    os16_hz_rp ro.tran_144hz_refresh_rate.support 0
    os16_hz_rp ro.tr_display.144hz.support 0
  fi
}

os16_apply_120hz_settings() {
  hz=$(os16_hz_target)
  [ "$hz" = "120" ] || [ "$hz" = "144" ] || return 0
  f="$hz.0"
  for ns in system global; do
    os16_put_hz "$ns" tran_refresh_mode "$hz"
    os16_put_hz "$ns" tran_need_recovery_refresh_mode "$hz"
    os16_put_hz "$ns" tran_need_recovery_refresh_rate "$hz"
    os16_put_hz "$ns" last_tran_refresh_mode_in_refresh_setting "$hz"
    os16_put_hz "$ns" tran_default_refresh_mode "$hz"
    os16_put_hz "$ns" peak_refresh_rate "$f"
    os16_put_hz "$ns" min_refresh_rate "$f"
    os16_put_hz "$ns" user_refresh_rate "$hz"
    os16_put_hz "$ns" preferred_refresh_rate "$hz"
    os16_put_hz "$ns" max_refresh_rate "$f"
    os16_put_hz "$ns" min_frame_rate "$hz"
    os16_put_hz "$ns" max_frame_rate "$hz"
    os16_put_hz "$ns" other_apps_refresh_rate "$hz"
    os16_put_hz "$ns" default_app_refresh_rate "$hz"
  done
  os16_put_hz secure user_refresh_rate "$hz"
  os16_put_hz global tran_default_auto_refresh.support 0
  os16_put_hz global tran_90hz_refresh_rate.not_support 1
  os16_put_hz global tran_low_battery_60hz_refresh_rate.support 0
  os16_put_hz global tran_custom_refresh_rate_config.support 1
  if [ "$hz" = "144" ]; then
    os16_put_hz global tran_144hz_refresh_rate.support 1
  fi
  cmd device_config put display_manager peak_refresh_rate_default "$hz" >/dev/null 2>&1
}

os16_apply_120hz_all() {
  os16_generate_120hz_jsons
  os16_bind_120hz_files
  os16_apply_120hz_props
  os16_apply_120hz_settings
  os16_write_app_defaults
}

if [ "${0##*/}" = "apply_120hz.sh" ]; then
  os16_apply_120hz_all
fi
