#!/system/bin/sh

MODDIR=${0%/*}
CFG="$MODDIR/config.json"
PFD_LOG="$MODDIR/post_fs_data.log"
rm -f "$PFD_LOG"
rm -rf "$MODDIR/.bootanim_restart.lock" "$MODDIR/.bootanim_restarted" "$MODDIR/.boot_play.wav"
rm -rf "$MODDIR/.charge_tr" "$MODDIR/.charge_prod" "$MODDIR/.charge_pick.mp4"
log_pfd() { echo "[$(date '+%H:%M:%S')] $1" >> "$PFD_LOG"; }

cfg_get() {
    [ -f "$CFG" ] || { echo "$2"; return; }
    val=$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" \
          | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
    [ -n "$val" ] && echo "$val" || echo "$2"
}

if [ -x /system/bin/nsenter ]; then
    NSENTER="/system/bin/nsenter -t 1 -m --"
elif command -v nsenter >/dev/null 2>&1; then
    NSENTER="nsenter -t 1 -m --"
else
    NSENTER=""
fi
log_pfd "nsenter: ${NSENTER:-none}"

ns_umount() {
    dest="$1"
    [ -n "$NSENTER" ] && $NSENTER umount -l "$dest" 2>/dev/null
    umount -l "$dest" 2>/dev/null
}

bind_over_file() {
    src="$1"
    dest="$2"
    [ -f "$src" ] || return 1
    [ -e "$dest" ] || { log_pfd "bind skip (no dest): $dest"; return 1; }
    chcon --reference="$dest" "$src" 2>/dev/null
    chmod 644 "$src" 2>/dev/null
    if [ -n "$NSENTER" ]; then
        $NSENTER umount -l "$dest" 2>/dev/null
        if $NSENTER mount --bind "$src" "$dest"; then
            log_pfd "bind OK (init) $dest"
            return 0
        fi
        log_pfd "bind init-ns FAIL $dest, trying local"
    fi
    umount -l "$dest" 2>/dev/null
    if mount --bind "$src" "$dest"; then
        log_pfd "bind OK (local) $dest"
        return 0
    fi
    log_pfd "bind FAIL $src -> $dest"
    return 1
}

try_bind_file() {
    src="$1"
    dest="$2"
    [ -f "$src" ] || return 1
    if [ ! -e "$dest" ]; then
        parent=$(dirname "$dest")
        if [ -d "$parent" ]; then
            if touch "$dest" 2>/dev/null; then
                log_pfd "created dest $dest"
            elif [ -n "$NSENTER" ] && $NSENTER touch "$dest" 2>/dev/null; then
                log_pfd "created dest (init) $dest"
            fi
        fi
    fi
    bind_over_file "$src" "$dest"
}

first_existing() {
    for p in "$@"; do
        [ -f "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

find_named() {
    name="$1"
    for root in /tr_product /product /system /system_ext /vendor /odm /oem /custom /apex; do
        [ -d "$root" ] || continue
        find "$root" -maxdepth 6 -name "$name" 2>/dev/null
    done
}

for dest in \
    /tr_product/media/bootanimation.zip \
    /tr_product/media/bootanimation-dark.zip \
    /product/media/bootanimation.zip \
    /system/product/media/bootanimation.zip \
    /system/media/bootanimation.zip \
    /oem/media/bootanimation.zip \
    /apex/com.android.bootanimation/etc/bootanimation.zip \
    /tr_product/media/shutdownanimation.zip \
    /product/media/shutdownanimation.zip \
    /system/product/media/shutdownanimation.zip \
    /system/media/shutdownanimation.zip \
    /oem/media/shutdownanimation.zip \
    /tr_product/media/userspace-reboot.zip \
    /product/media/userspace-reboot.zip \
    /system/media/userspace-reboot.zip
do
    ns_umount "$dest"
done
ns_umount /tr_product/media
ns_umount /tr_product/theme/charge
ns_umount /product/theme/charge
ns_umount /system/product/theme/charge

# Drop failed-feature leftovers from earlier Flagship 16 builds.
rm -rf "$MODDIR/system/product/theme/charge" \
       "$MODDIR/tr_product/theme/charge" \
       "$MODDIR/product/theme/charge" \
       "$MODDIR/system/product/media/audio" \
       "$MODDIR/tr_product/media/audio" \
       "$MODDIR/product/media/audio"
rm -rf /mnt/vendor/mountify/tr_product/theme/charge \
       /mnt/vendor/mountify/product/theme/charge \
       /mnt/vendor/mountify/tr_product/media/audio/bootsound
rm -f /data/local/bootaudio.mp3 /data/local/shutaudio.mp3

ANIM_DIR=""
for d in \
    "$MODDIR/product/theme/animations" \
    "$MODDIR/system/product/theme/animations" \
    /mnt/vendor/mountify/product/theme/animations \
    /mnt/vendor/mountify/system/product/theme/animations
do
    found=""
    for f in "$d"/bootanim_*.zip; do
        [ -f "$f" ] && found="$f" && break
    done
    if [ -n "$found" ]; then
        ANIM_DIR="$d"
        break
    fi
done
if [ -z "$ANIM_DIR" ]; then
    hit=$(find "$MODDIR" /mnt/vendor/mountify -name 'bootanim_*.zip' 2>/dev/null | head -n 1)
    [ -n "$hit" ] && ANIM_DIR=$(dirname "$hit")
fi
log_pfd "ANIM_DIR=$ANIM_DIR"
[ -n "$ANIM_DIR" ] && ls -la "$ANIM_DIR" >> "$PFD_LOG" 2>/dev/null
log_pfd "live /tr_product/media:"
ls -la /tr_product/media >> "$PFD_LOG" 2>/dev/null

BA_STYLE=$(cfg_get bootanim_style "hios16")
RA_STYLE=$(cfg_get rebootanim_style "hios16")
[ -z "$RA_STYLE" ] && RA_STYLE=$(cfg_get shutdownanim_style "hios16")
log_pfd "bootanim_style=$BA_STYLE rebootanim_style=$RA_STYLE"

pick_pack_zip() {
    style="$1"
    custom_name="$2"
    hit=""
    case "$style" in
        off) return 1 ;;
        custom)
            hit=$(first_existing \
                "$MODDIR/tr_product/media/${custom_name}" \
                "$MODDIR/product/media/${custom_name}" \
                "$MODDIR/system/product/media/${custom_name}" \
                "$MODDIR/system/media/${custom_name}")
            ;;
        *)
            hit=$(first_existing \
                "$ANIM_DIR/bootanim_$style.zip" \
                "$MODDIR/product/theme/animations/bootanim_$style.zip" \
                "$MODDIR/system/product/theme/animations/bootanim_$style.zip")
            [ -n "$hit" ] || hit=$(find "$MODDIR" -name "bootanim_${style}.zip" 2>/dev/null | head -n 1)
            ;;
    esac
    [ -n "$hit" ] && echo "$hit"
}

bind_media_zip() {
    src="$1"
    name="$2"
    [ -f "$src" ] || return 1
    try_bind_file "$src" "/tr_product/media/$name"
    try_bind_file "$src" "/product/media/$name"
    try_bind_file "$src" "/system/product/media/$name"
    try_bind_file "$src" "/system/media/$name"
    try_bind_file "$src" "/oem/media/$name"
    for dest in $(find_named "$name"); do
        bind_over_file "$src" "$dest"
    done
}

TRP_STAGE="$MODDIR/tr_product/media"
mkdir -p "$TRP_STAGE"
rm -f "$TRP_STAGE/bootanimation.zip" "$TRP_STAGE/bootanimation-dark.zip" "$TRP_STAGE/shutdownanimation.zip"

SRC=""
if [ "$BA_STYLE" = "off" ]; then
    log_pfd "bootanim: off — leave stock zip"
else
    SRC=$(pick_pack_zip "$BA_STYLE" "bootanimation_custom.zip")
    if [ -z "$SRC" ] && [ "$BA_STYLE" = "custom" ]; then
        for dir in "$MODDIR/tr_product/media" "$MODDIR/product/media" "$MODDIR/system/product/media"; do
            for f in "$dir"/bootanimation_custom.*; do
                [ -f "$f" ] || continue
                SRC="$f"
                break
            done
            [ -n "$SRC" ] && break
        done
    fi
    if [ -n "$SRC" ]; then
        cp -f "$SRC" "$TRP_STAGE/bootanimation.zip"
        chmod 644 "$TRP_STAGE/bootanimation.zip" 2>/dev/null
        log_pfd "bootanim staged from $SRC style=$BA_STYLE"
    else
        log_pfd "bootanim: no module zip to stage (style=$BA_STYLE)"
    fi
fi

SRC_REBOOT=""
if [ "$RA_STYLE" = "off" ]; then
    log_pfd "rebootanim: off — leave stock shutdown zip"
else
    SRC_REBOOT=$(pick_pack_zip "$RA_STYLE" "shutdownanimation_custom.zip")
    if [ -z "$SRC_REBOOT" ]; then
        SRC_REBOOT=$(pick_pack_zip "$RA_STYLE" "rebootanimation_custom.zip")
    fi
    if [ -z "$SRC_REBOOT" ] && [ "$RA_STYLE" = "custom" ]; then
        for dir in "$MODDIR/tr_product/media" "$MODDIR/product/media" "$MODDIR/system/product/media"; do
            for f in "$dir"/shutdownanimation_custom.* "$dir"/rebootanimation_custom.*; do
                [ -f "$f" ] || continue
                SRC_REBOOT="$f"
                break
            done
            [ -n "$SRC_REBOOT" ] && break
        done
    fi
    if [ -n "$SRC_REBOOT" ]; then
        cp -f "$SRC_REBOOT" "$TRP_STAGE/shutdownanimation.zip"
        chmod 644 "$TRP_STAGE/shutdownanimation.zip" 2>/dev/null
        log_pfd "rebootanim staged from $SRC_REBOOT style=$RA_STYLE"
    else
        log_pfd "rebootanim: no module zip to stage (style=$RA_STYLE)"
    fi
fi

STAGED="$TRP_STAGE/bootanimation.zip"
if [ -f "$STAGED" ]; then
    bind_over_file "$STAGED" /tr_product/media/bootanimation.zip
    bind_over_file "$STAGED" /tr_product/media/bootanimation-dark.zip
    bind_over_file "$STAGED" /product/media/bootanimation.zip
    bind_over_file "$STAGED" /system/product/media/bootanimation.zip
    bind_over_file "$STAGED" /system/media/bootanimation.zip
    bind_over_file "$STAGED" /oem/media/bootanimation.zip
    bind_over_file "$STAGED" /apex/com.android.bootanimation/etc/bootanimation.zip
    for dest in $(find_named bootanimation.zip) $(find_named bootanimation-dark.zip); do
        bind_over_file "$STAGED" "$dest"
    done
    log_pfd "bootanim bind pass done"
fi

STAGED_REBOOT="$TRP_STAGE/shutdownanimation.zip"
if [ -f "$STAGED_REBOOT" ]; then
    bind_media_zip "$STAGED_REBOOT" shutdownanimation.zip
    bind_media_zip "$STAGED_REBOOT" userspace-reboot.zip
    log_pfd "rebootanim bind pass done"
    ls -l /tr_product/media/shutdownanimation.zip >> "$PFD_LOG" 2>/dev/null
fi
log_pfd "live /tr_product/media:"
ls -la /tr_product/media >> "$PFD_LOG" 2>/dev/null

# Status bar: only a user-uploaded overlay. Bundled iOS / XOS 16 APKs from
# V1.14 are deleted so they cannot keep applying.
rm -rf "$MODDIR/system/overlay/Icons_Signal_wifi" \
       "$MODDIR/system/product/overlay/Icons_Signal_wifi" \
       "$MODDIR/product/overlay/Icons_Signal_wifi" \
       /mnt/vendor/mountify/system/overlay/Icons_Signal_wifi \
       /mnt/vendor/mountify/system/product/overlay/Icons_Signal_wifi \
       /mnt/vendor/mountify/product/overlay/Icons_Signal_wifi
rm -f "$MODDIR/system/overlay/SystemUISignalOverlay.apk" \
      "$MODDIR/system/overlay/SystemUISignalOverlay.apk.disabled" \
      "$MODDIR/system/product/overlay/SystemUISignalOverlay.apk" \
      "$MODDIR/system/product/overlay/SystemUISignalOverlay.apk.disabled" \
      "$MODDIR/product/overlay/SystemUISignalOverlay.apk" \
      "$MODDIR/product/overlay/SystemUISignalOverlay.apk.disabled"

SB_STYLE=$(cfg_get statusbar_style "off")
[ "$SB_STYLE" = "ios" ] && SB_STYLE=off
[ "$SB_STYLE" = "xos16" ] && SB_STYLE=off
log_pfd "statusbar_style=$SB_STYLE"

sb_disable() {
    f="$1"
    [ -f "$f" ] && mv "$f" "${f}.disabled"
}
sb_enable() {
    f="$1"
    [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
}

CUSTOM_APKS="
$MODDIR/system/overlay/Icons_Signal_wifi_custom.apk
$MODDIR/system/product/overlay/Icons_Signal_wifi_custom.apk
$MODDIR/product/overlay/Icons_Signal_wifi_custom.apk
/mnt/vendor/mountify/system/overlay/Icons_Signal_wifi_custom.apk
/mnt/vendor/mountify/system/product/overlay/Icons_Signal_wifi_custom.apk
/mnt/vendor/mountify/product/overlay/Icons_Signal_wifi_custom.apk
"

for f in $CUSTOM_APKS; do
    sb_disable "$f"
done
if [ "$SB_STYLE" = "custom" ]; then
    for f in $CUSTOM_APKS; do sb_enable "$f"; done
fi

have_custom=no
for f in $CUSTOM_APKS; do
    if [ -f "$f" ]; then
        have_custom=yes
        break
    fi
done
log_pfd "custom overlay: $have_custom"

# Blur: stock liquid glass is already 1 in /tr_product/etc/build.prop.
# Magisk system.prop does not win for those keys. resetprop here (before
# zygote) and again from service.sh after overlay.
if [ -f "$MODDIR/apply_blur.sh" ]; then
  . "$MODDIR/apply_blur.sh"
  os16_apply_blur_props
  log_pfd "blur props resetprop liquidglass=$(getprop ro.tr_display.liquidglass.support 2>/dev/null) sf_disable=$(getprop persist.sys.sf.disable_blurs 2>/dev/null)"
else
  log_pfd "apply_blur.sh missing"
fi

# Refresh: Mountify does not overlay /tr_product (targets are product/vendor/…).
# Same per-file bind as bootanimation.zip. Do this at post-fs before Magellan loads.
if [ -f "$MODDIR/apply_120hz.sh" ]; then
  . "$MODDIR/apply_120hz.sh"
  if os16_hz_on; then
    os16_generate_120hz_jsons
    os16_copy_magellan_mountify
    os16_bind_magellan_bootanim
    log_pfd "magellan bind dests:"
    ls -l /tr_product/etc/vconfig/magellan/refresh_rate_config.xml /product/etc/vconfig/magellan/refresh_rate_config.xml "$MAGELLAN_XML" >> "$PFD_LOG" 2>/dev/null
    grep -c 'max="144"' /tr_product/etc/vconfig/magellan/refresh_rate_config.xml >> "$PFD_LOG" 2>/dev/null
    grep -o 'input_method_switch>[^<]*' /tr_product/etc/vconfig/magellan/refresh_rate_config.xml >> "$PFD_LOG" 2>/dev/null
  else
    os16_copy_magellan_mountify
    log_pfd "refresh force_120hz=false"
  fi
  os16_swap_magisk_apm
else
  log_pfd "apply_120hz.sh missing"
fi
