#!/system/bin/sh
# Flagship 16 Force 120Hz — XOS 16 Magellan via Mountify overlay.
# Customize App Refresh reads /tr_product/etc/vconfig/magellan/refresh_rate_config.xml
#   max="144"  → “Apps Supporting 144 Hz” and 144 in the picker
#   auto="120" → listed default for that app
# TranOS 16 custom refresh.zip (t.me/nyellnpr/35509) is a 15.6KB Magellan XML
# flashed with Mountify. Magisk bind of /tr_product loses when Mountify remounts.
# Per-file copy into /mnt/vendor/mountify/tr_product/... — never bind-dir /tr_product.

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
MAGELLAN_XML="$MAGELLAN_DIR/refresh_rate_config.xml"

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
  mkdir -p "$MAGELLAN_DIR"
  stockbak="$MAGELLAN_DIR/refresh_rate_config.xml.stock"
  os16_magellan_dests | awk 'NF && !seen[$0]++' | while IFS= read -r dest; do
    os16_120hz_umount "$dest"
    if [ -f "$dest" ] && [ ! -f "$stockbak" ]; then
      if ! grep -q 'version="20260827"' "$dest" 2>/dev/null; then
        cp "$dest" "$stockbak"
      fi
    fi
    if os16_hz_on; then
      os16_try_bind_file "$MAGELLAN_XML" "$dest"
    fi
  done
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
    pm list packages 2>/dev/null | sed 's/^package://'
    pm list packages -s 2>/dev/null | sed 's/^package://'
    pm list packages -3 2>/dev/null | sed 's/^package://'
    pm list packages -a 2>/dev/null | sed 's/^package://'
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
  mkdir -p "$MAGELLAN_DIR"
  tmp="$HZDIR/.pkgs.txt"
  [ -f "$tmp" ] || return 1
  stock=""
  for cand in \
    "$MAGELLAN_DIR/refresh_rate_config.xml.stock" \
    /tr_product/etc/vconfig/magellan/refresh_rate_config.xml \
    /mnt/vendor/mountify/tr_product/etc/vconfig/magellan/refresh_rate_config.xml \
    /product/etc/vconfig/magellan/refresh_rate_config.xml \
    /system_ext/etc/vconfig/magellan/refresh_rate_config.xml
  do
    if [ -f "$cand" ] && grep -q '<WHITELIST>' "$cand" 2>/dev/null; then
      if ! grep -q 'version="20260827"' "$cand" 2>/dev/null; then
        stock="$cand"
        break
      fi
    fi
  done
  switchf="$MAGELLAN_DIR/.switch.xml"
  actf="$MAGELLAN_DIR/.activity.xml"
  if [ -n "$stock" ]; then
    awk '
      /<WHITELIST>/ { skip=1; next }
      /<\/WHITELIST>/ { skip=0; next }
      skip { next }
      { print }
    ' "$stock" > "$MAGELLAN_DIR/.stock_stripped.xml"
    awk '
      BEGIN { keep=0 }
      /<switch>/ { keep=1 }
      keep { print }
      /<\/switch>/ { keep=0 }
    ' "$MAGELLAN_DIR/.stock_stripped.xml" > "$switchf"
    awk '
      BEGIN { keep=0 }
      /<activity>/ { keep=1 }
      keep { print }
      /<\/activity>/ { keep=0 }
    ' "$MAGELLAN_DIR/.stock_stripped.xml" > "$actf"
  fi
  [ -s "$switchf" ] || cat > "$switchf" <<'EOF'
    <switch>
        <input_method_switch>true</input_method_switch>
        <navigation_switch>true</navigation_switch>
        <video_switch>true</video_switch>
        <audio_switch>true</audio_switch>
        <high_temperature_threshold>0</high_temperature_threshold>
        <high_temperature_refresh_rate>0</high_temperature_refresh_rate>
        <camera_notification_high_temerature_switch>false</camera_notification_high_temerature_switch>
        <high_temperature_white_list_switch>false</high_temperature_white_list_switch>
        <multi_window_refresh_rate>120</multi_window_refresh_rate>
        <screen_record>60</screen_record>
    </switch>
EOF
  [ -s "$actf" ] || cat > "$actf" <<'EOF'
    <activity>
    </activity>
EOF
  # Same as TranOS 16 custom refresh (Mountify): 120Hz split-screen, not stock 60.
  if [ -s "$switchf" ]; then
    sed 's/<multi_window_refresh_rate>[0-9][0-9]*<\/multi_window_refresh_rate>/<multi_window_refresh_rate>120<\/multi_window_refresh_rate>/' "$switchf" > "$switchf.new" && mv "$switchf.new" "$switchf"
  fi
  {
    echo '<?xml version="1.0" encoding="UTF-8" ?>'
    echo '<refresh_rate_config version="20260827">'
    cat "$switchf"
    echo '    <WHITELIST>'
    awk '{
      printf "        <item package=\"%s\" auto=\"120\" high=\"120\" max=\"144\" touch=\"1\" app_request=\"0\"/>\n", $0
    }' "$tmp"
    echo '    </WHITELIST>'
    cat "$actf"
    echo '</refresh_rate_config>'
  } > "$MAGELLAN_XML"
  chmod 644 "$MAGELLAN_XML" 2>/dev/null
}

os16_copy_magellan_mountify() {
  dest_mod="$MODDIR/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
  dest_mfy="/mnt/vendor/mountify/tr_product/etc/vconfig/magellan/refresh_rate_config.xml"
  if ! os16_hz_on; then
    rm -f "$dest_mod" "$dest_mfy"
    return 0
  fi
  [ -f "$MAGELLAN_XML" ] || return 0
  mkdir -p "$(dirname "$dest_mod")"
  cp -f "$MAGELLAN_XML" "$dest_mod"
  chmod 644 "$dest_mod" 2>/dev/null
  # Mountify owns overlay on /tr_product. Magisk bind of that path loses after
  # the metamodule remounts. Drop the XML into Mountify's tree like the
  # TranOS 16 custom refresh zip (flash with Mountify).
  if [ -d /mnt/vendor/mountify/tr_product ]; then
    mkdir -p "$(dirname "$dest_mfy")"
    cp -f "$MAGELLAN_XML" "$dest_mfy"
    chmod 644 "$dest_mfy" 2>/dev/null
  fi
}

os16_copy_magellan_data() {
  os16_hz_on || return 0
  [ -f "$MAGELLAN_XML" ] || return 0
  mkdir -p /data/magellan 2>/dev/null
  cp -f "$MAGELLAN_XML" /data/magellan/refresh_rate_config.xml 2>/dev/null
  chmod 644 /data/magellan/refresh_rate_config.xml 2>/dev/null
  chown system:system /data/magellan/refresh_rate_config.xml 2>/dev/null
  find /data/magellan -maxdepth 3 -type f \( -name '*refresh*' -o -name '*Refresh*' \) 2>/dev/null | while IFS= read -r f; do
    [ "$f" = /data/magellan/refresh_rate_config.xml ] && continue
    case "$f" in
      *.xml|*.json) cp -f "$MAGELLAN_XML" "$f" 2>/dev/null ;;
    esac
  done
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
  am force-stop com.android.settings >/dev/null 2>&1
  am force-stop com.transsion.ossettingsext >/dev/null 2>&1
}

os16_apply_120hz_all() {
  os16_generate_120hz_jsons
  os16_copy_magellan_mountify
  os16_bind_120hz_files
  os16_copy_magellan_data
  os16_apply_120hz_settings
}

if [ "${0##*/}" = "apply_120hz.sh" ]; then
  os16_apply_120hz_all
fi
