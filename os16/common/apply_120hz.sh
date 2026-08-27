#!/system/bin/sh
# Flagship 16 Force 120Hz — same path that worked on XOS 15:
# Magisk overlay of /product/apm/config/*.json (TranRefreshRatePolicy reads
# Environment.getProductDirectory()/apm/config/, not /tr_product).
# That unlocks 144Hz as a choice on Customize App Refresh for every app.
# There is no separate 144 toggle. Off does not write a fake 60Hz default.

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"
APM_CONFIG="$MODDIR/system/product/apm/config"
APM_BYPASS="$MODDIR/system/product/apm/config_120hz_bypass"
# leftover from V1.39–1.41
if [ ! -d "$APM_BYPASS" ] && [ -d "$MODDIR/apm_120hz_bypass" ]; then
  APM_BYPASS="$MODDIR/apm_120hz_bypass"
fi
HZDIR="$APM_BYPASS"

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

os16_try_bind_file() {
  src="$1"
  dest="$2"
  [ -f "$src" ] || return 1
  if [ ! -e "$dest" ]; then
    parent=$(dirname "$dest")
    if [ -d "$parent" ]; then
      touch "$dest" 2>/dev/null
      NS=$(os16_120hz_nsenter)
      [ -e "$dest" ] || { [ -n "$NS" ] && $NS touch "$dest" 2>/dev/null; }
    fi
  fi
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

os16_product_apm_dests() {
  name="$1"
  echo "/product/apm/config/$name"
  echo "/system/product/apm/config/$name"
  echo "/tr_product/etc/apm/config/$name"
  echo "/tr_product/apm/config/$name"
}

os16_swap_magisk_apm() {
  mkdir -p "$APM_CONFIG"
  for name in refresh_rate_config.json project_refresh_rate_config.json; do
    real="$APM_CONFIG/$name"
    bypass="$APM_BYPASS/$name"
    backup="$APM_CONFIG/${name}.stock"
    if os16_hz_on; then
      [ -f "$bypass" ] || continue
      if [ ! -f "$backup" ] && [ -f "$real" ]; then
        cp "$real" "$backup"
      fi
      cp -f "$bypass" "$real"
    else
      if [ -f "$backup" ]; then
        cp -f "$backup" "$real"
      fi
    fi
    chmod 644 "$real" 2>/dev/null
  done
}

os16_bind_120hz_files() {
  os16_swap_magisk_apm
  for name in refresh_rate_config.json project_refresh_rate_config.json; do
    src="$APM_CONFIG/$name"
    [ -f "$src" ] || src="$APM_BYPASS/$name"
    os16_product_apm_dests "$name" | awk 'NF && !seen[$0]++' | while IFS= read -r dest; do
      os16_120hz_umount "$dest"
      if os16_hz_on; then
        os16_try_bind_file "$src" "$dest"
      fi
    done
  done
}

os16_write_pkg_array() {
  tmp="$HZDIR/.pkgs.txt"
  mkdir -p "$HZDIR"
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
  echo "$n" > "$APM_CONFIG/.pkg_count" 2>/dev/null
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
  mkdir -p "$APM_BYPASS" "$APM_CONFIG"
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
  for json in "$APM_BYPASS/refresh_rate_config.json" "$APM_BYPASS/project_refresh_rate_config.json"; do
    [ -f "$json" ] || continue
    os16_json_replace_top_array "$json" auto_refresh_rate_whitelist "$arr"
    os16_json_replace_top_array "$json" slide_in_higher_setting_mode_120hz "$arr"
    os16_json_replace_top_array "$json" high_refresh_rate_gameList_in_120hz_mode "$arr"
    os16_json_replace_top_array "$json" limit_60hz_in_all_setting_mode "$empty"
    os16_json_replace_top_array "$json" limit_90hz_in_higher_setting_mode "$empty"
    os16_json_replace_top_array "$json" limit_120hz_in_auto_mode "$empty"
    os16_json_replace_top_array "$json" app_request_black_list "$empty"
    os16_json_replace_top_array "$json" refresh_rate_90hz_whitelist_in_120hz_mode "$empty"
    os16_json_replace_top_array "$json" refresh_rate_blacklist_in_90hz_mode "$empty"
    os16_json_replace_top_array "$json" min_refresh_rate_90hz_in_auto_mode "$empty"
  done
}

os16_put_hz() {
  ns="$1"; key="$2"; val="$3"
  settings put "$ns" "$key" "$val" >/dev/null 2>&1
}

os16_apply_120hz_settings() {
  os16_hz_on || return 0
  # Same six keys Flagship 15 wrote into Settings on this X6886.
  os16_put_hz system tran_refresh_mode 120
  os16_put_hz system tran_need_recovery_refresh_mode 120
  os16_put_hz system tran_need_recovery_refresh_rate 120
  os16_put_hz system last_tran_refresh_mode_in_refresh_setting 120
  os16_put_hz system peak_refresh_rate 120.0
  os16_put_hz system min_refresh_rate 120.0
}

os16_apply_120hz_all() {
  os16_generate_120hz_jsons
  os16_bind_120hz_files
  os16_apply_120hz_settings
}

if [ "${0##*/}" = "apply_120hz.sh" ]; then
  os16_apply_120hz_all
fi
