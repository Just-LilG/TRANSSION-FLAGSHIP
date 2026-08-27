#!/system/bin/sh
# Flagship 16 Force 120Hz: default 120 for every installed package
# (system + user). Flagship 15 never confirmed this on X6886.
# Generate APM lists when pm is up (late_start / WebUI Apply), not
# post-fs-data. Bind per-file only — never bind-dir /tr_product.
# Off does not write a fake 60Hz default.

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

os16_hz_on() {
  on=$(os16_cfg_bool force_120hz false)
  [ "$on" = "true" ] || [ "$on" = "1" ]
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
  # stdout: pretty JSON array of every package pm can see
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
  # pm not ready yet — keep shipped / last generated lists
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
  done
}

os16_put_hz() {
  ns="$1"; key="$2"; val="$3"
  settings put "$ns" "$key" "$val" >/dev/null 2>&1
}

os16_apply_120hz_settings() {
  os16_hz_on || return 0
  for ns in system global; do
    os16_put_hz "$ns" tran_refresh_mode 120
    os16_put_hz "$ns" tran_need_recovery_refresh_mode 120
    os16_put_hz "$ns" tran_need_recovery_refresh_rate 120
    os16_put_hz "$ns" last_tran_refresh_mode_in_refresh_setting 120
    os16_put_hz "$ns" peak_refresh_rate 120.0
    os16_put_hz "$ns" min_refresh_rate 120.0
    os16_put_hz "$ns" user_refresh_rate 120
    os16_put_hz "$ns" preferred_refresh_rate 120
  done
  if command -v resetprop >/dev/null 2>&1; then
    resetprop persist.sys.peak_refresh_rate 120 >/dev/null 2>&1
    resetprop persist.sys.min_refresh_rate 120 >/dev/null 2>&1
  else
    setprop persist.sys.peak_refresh_rate 120 >/dev/null 2>&1
    setprop persist.sys.min_refresh_rate 120 >/dev/null 2>&1
  fi
  cmd device_config put display_manager peak_refresh_rate_default 120 >/dev/null 2>&1
  device_config put display_manager peak_refresh_rate_default 120 >/dev/null 2>&1
}

os16_apply_120hz_all() {
  os16_generate_120hz_jsons
  os16_bind_120hz_files
  os16_apply_120hz_settings
}

if [ "${0##*/}" = "apply_120hz.sh" ]; then
  os16_apply_120hz_all
fi
