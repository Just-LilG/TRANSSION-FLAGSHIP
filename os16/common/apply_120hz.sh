#!/system/bin/sh
# Flagship 16 Force 120Hz = the working TranOS 16 custom refresh.zip:
# ONLY Magellan XML at $MODDIR/system/tr_product/etc/vconfig/magellan/refresh_rate_config.xml
# Mountify copies system/* then overlays /tr_product. Do not umount/bind that dest
# (that fights Mountify). Do not rewrite auto/high/touch — listed 90 is the OEM
# saved default; max="144" is what puts 144 in Customize App Refresh.

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"
APM_CONFIG="$MODDIR/system/product/apm/config"
APM_BYPASS="$MODDIR/system/product/apm/config_120hz_bypass"
if [ ! -d "$APM_BYPASS" ] && [ -d "$MODDIR/apm_120hz_bypass" ]; then
  APM_BYPASS="$MODDIR/apm_120hz_bypass"
fi
HZDIR="$APM_BYPASS"
MAGELLAN_DIR="$MODDIR/magellan"
MAGELLAN_XML="$MODDIR/system/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
MAGELLAN_TEMPLATE="$MAGELLAN_DIR/refresh_rate_config.xml"

os16_cfg_bool() {
  k="$1"; d="$2"
  [ -f "$CFG" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

os16_hz_on() {
  if [ -f "$MODDIR/.force_120hz" ]; then
    f=$(tr -d ' \r\n' < "$MODDIR/.force_120hz" 2>/dev/null)
    [ "$f" = "1" ] && return 0
    [ "$f" = "true" ] && return 0
    [ "$f" = "0" ] && return 1
    [ "$f" = "false" ] && return 1
  fi
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
  parent=$(dirname "$dest")
  if [ ! -e "$dest" ]; then
    mkdir -p "$parent" 2>/dev/null
    NS=$(os16_120hz_nsenter)
    [ -d "$parent" ] || { [ -n "$NS" ] && $NS mkdir -p "$parent" 2>/dev/null; }
    touch "$dest" 2>/dev/null
    [ -e "$dest" ] || { [ -n "$NS" ] && $NS touch "$dest" 2>/dev/null; }
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

os16_magellan_dests() {
  echo "/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
  echo "/mnt/vendor/mountify/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
  echo "/product/etc/vconfig/magellan/refresh_rate_config.xml"
  echo "/system/product/etc/vconfig/magellan/refresh_rate_config.xml"
  echo "/system_ext/etc/vconfig/magellan/refresh_rate_config.xml"
  echo "/vendor/etc/vconfig/magellan/refresh_rate_config.xml"
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
  # Product APM JSON is leftover XOS 15 overlay. OS 16 Magellan does not use it
  # for the 144 picker. Never umount /tr_product Magellan — that unmounts Mountify.
  os16_swap_magisk_apm
}

os16_write_pkg_array() {
  tmp="$HZDIR/.pkgs.txt"
  mkdir -p "$HZDIR" "$MAGELLAN_DIR"
  {
    echo android
    echo com.android.systemui
    echo com.android.settings
    echo com.sh.smart.caller
    echo com.google.android.apps.messaging
    echo com.transsion.smartmessage
    echo com.google.android.dialer
    echo com.android.phone
    echo com.transsion.XOSLauncher
    echo com.transsion.hilauncher
    echo com.transsion.launcher3
    echo com.transsion.itel.launcher
    if [ -f /data/system/packages.list ]; then
      awk '{print $1}' /data/system/packages.list
    fi
    if [ -f /data/system/packages.xml ]; then
      grep -oE 'name="[A-Za-z0-9._]+"' /data/system/packages.xml | sed 's/name="//;s/"$//'
    fi
  } 2>/dev/null | tr -d '\r' | grep -E '^[A-Za-z0-9._]+$' | sort -u > "$tmp"
  n=$(wc -l < "$tmp" 2>/dev/null | tr -d ' ')
  [ -z "$n" ] && n=0
  echo "$n" > "$HZDIR/.pkg_count"
  echo "$n" > "$APM_CONFIG/.pkg_count" 2>/dev/null
  echo "$n" > "$MAGELLAN_DIR/.pkg_count" 2>/dev/null
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

os16_generate_magellan_xml() {
  # Exact TranOS 16 custom refresh.xml. Do not rewrite existing items
  # (V1.43–1.46 forced auto=120 and touch=0; Magellan then differed from the
  # zip that actually unlocked 144). Append only packages not already listed.
  mkdir -p "$(dirname "$MAGELLAN_XML")" "$MAGELLAN_DIR"
  [ -f "$MAGELLAN_TEMPLATE" ] || return 1
  tmp="$HZDIR/.pkgs.txt"
  out="$MAGELLAN_XML"
  if [ ! -f "$tmp" ]; then
    cp -f "$MAGELLAN_TEMPLATE" "$out"
    chmod 644 "$out" 2>/dev/null
    return 0
  fi
  awk -v pkgfile="$tmp" '
    BEGIN {
      while ((getline p < pkgfile) > 0) {
        if (p != "") need[p] = 1
      }
      close(pkgfile)
    }
    /<item/ && /package="/ {
      pkg = ""
      if (match($0, /package="[^"]+"/)) {
        pkg = substr($0, RSTART + 9, RLENGTH - 10)
      }
      if (pkg != "") seen[pkg] = 1
      print
      next
    }
    /<\/WHITELIST>/ {
      for (p in need) {
        if (!seen[p]) {
          printf "    <item package=\"%s\" auto=\"90\" high=\"120\" touch=\"1\" app_request=\"0\" max=\"144\"/>\n", p
        }
      }
      print
      next
    }
    { print }
  ' "$MAGELLAN_TEMPLATE" > "$out"
  [ -s "$out" ] || cp -f "$MAGELLAN_TEMPLATE" "$out"
  chmod 644 "$out" 2>/dev/null
}

os16_copy_magellan_mountify() {
  dest_mfy="/mnt/vendor/mountify/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
  if ! os16_hz_on; then
    rm -f "$MAGELLAN_XML" "$dest_mfy"
    rm -f "$MODDIR/system/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
    return 0
  fi
  mkdir -p "$(dirname "$MAGELLAN_XML")"
  if [ ! -f "$MAGELLAN_XML" ] && [ -f "$MAGELLAN_TEMPLATE" ]; then
    cp -f "$MAGELLAN_TEMPLATE" "$MAGELLAN_XML"
  fi
  [ -f "$MAGELLAN_XML" ] || return 0
  chmod 644 "$MAGELLAN_XML" 2>/dev/null
  if [ -d /mnt/vendor/mountify/tr_product ] || [ -d /mnt/vendor/mountify ]; then
    mkdir -p "$(dirname "$dest_mfy")"
    cp -f "$MAGELLAN_XML" "$dest_mfy" 2>/dev/null
    chmod 644 "$dest_mfy" 2>/dev/null
  fi
}

os16_copy_magellan_data() {
  # Working zip never writes /data/magellan. Do not overwrite magellan.db json.
  return 0
}

os16_generate_120hz_jsons() {
  os16_hz_on || return 0
  mkdir -p "$APM_BYPASS" "$APM_CONFIG" "$MAGELLAN_DIR"
  arr="$HZDIR/.all_pkgs.jsonarray"
  empty="$HZDIR/.empty.jsonarray"
  echo '[]' > "$empty"
  os16_write_pkg_array > "$arr"
  os16_generate_magellan_xml
  n=$(cat "$HZDIR/.pkg_count" 2>/dev/null)
  [ -z "$n" ] && n=0
  if [ "$n" -lt 8 ]; then
    echo "pm-not-ready:$n" > "$HZDIR/.pkg_count"
  fi
  for json in "$APM_BYPASS/refresh_rate_config.json" "$APM_BYPASS/project_refresh_rate_config.json"; do
    [ -f "$json" ] || continue
    [ "$n" -lt 8 ] && continue
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
  os16_put_hz system tran_refresh_mode 120
  os16_put_hz system tran_need_recovery_refresh_mode 120
  os16_put_hz system tran_need_recovery_refresh_rate 120
  os16_put_hz system last_tran_refresh_mode_in_refresh_setting 120
  os16_put_hz system peak_refresh_rate 120.0
  os16_put_hz system min_refresh_rate 120.0
  os16_put_hz system other_apps_refresh_rate 120
  os16_put_hz system default_app_refresh_rate 120
  os16_put_hz system tran_other_app_refresh_rate 120
  resetprop ro.tr_display.refreshrate.default_refreshmode.config 120 >/dev/null 2>&1
}

os16_apply_120hz_all() {
  os16_generate_120hz_jsons
  os16_copy_magellan_mountify
  os16_bind_120hz_files
  os16_copy_magellan_data
  os16_apply_120hz_settings
}

# WebUI Apply: copy the TranOS XML into the module tree for the next Mountify
# boot. Do not wipe package_cache (that soft-reboots and can lose config.json),
# do not force-stop Settings, do not call pm.
os16_webui_apply_120hz() {
  if os16_hz_on; then
    mkdir -p "$(dirname "$MAGELLAN_XML")"
    if [ -f "$MAGELLAN_TEMPLATE" ]; then
      cp -f "$MAGELLAN_TEMPLATE" "$MAGELLAN_XML"
      chmod 644 "$MAGELLAN_XML" 2>/dev/null
    fi
  fi
  os16_copy_magellan_mountify
  os16_swap_magisk_apm
}

if [ "${0##*/}" = "apply_120hz.sh" ]; then
  os16_webui_apply_120hz
fi
