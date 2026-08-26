#!/system/bin/sh

MODDIR=${0%/*}
CFG="$MODDIR/config.json"
PFD_LOG="$MODDIR/post_fs_data.log"
rm -f "$PFD_LOG"
log_pfd() { echo "[$(date '+%H:%M:%S')] $1" >> "$PFD_LOG"; }

cfg_get() {
    [ -f "$CFG" ] || { echo "$2"; return; }
    val=$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" \
          | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
    [ -n "$val" ] && echo "$val" || echo "$2"
}
cfg_bool() { [ "$(cfg_get "$1" "$2")" = "true" ] && echo 1 || echo 0; }

# Same rule as install.sh is_xos16: XOS + version 16.x. Used so a missing
# config key does not turn charging anim / FOD / status-bar overlay on for XOS 16.
is_xos16() {
    local type ver
    type=$(getprop ro.tran.os.type 2>/dev/null)
    ver=$(getprop ro.transsion.os.version 2>/dev/null)
    if [ -f "$MODDIR/install_diagnostic.txt" ]; then
        [ -z "$type" ] && type=$(grep '^detected_OS_TYPE=' "$MODDIR/install_diagnostic.txt" | cut -d= -f2- | tr -d '\r')
        [ -z "$ver" ] && ver=$(grep '^detected_OS_VER=' "$MODDIR/install_diagnostic.txt" | cut -d= -f2- | tr -d '\r')
    fi
    [ "$type" = "XOS" ] || return 1
    echo "$ver" | grep -qiE '^(xos[-_. ]*)?16([^0-9].*)?$'
}
if is_xos16; then
    CA_DEF=false
    FOD_DEF=false
    SB_DEF=off
else
    CA_DEF=true
    FOD_DEF=true
    SB_DEF=xos16
fi

log_pfd "config.json exists: $([ -f "$CFG" ] && echo yes || echo no)"

# OverlayFS / Magic Mount of /product happens too late for bootanim (and on
# KernelSU may not happen at all without a metamodule). XOS 16 on this
# device stores the zip at /tr_product/media/bootanimation.zip — not
# /product or /system. Bind in init's mount namespace so bootanim sees it.
if [ -x /system/bin/nsenter ]; then
    NSENTER="/system/bin/nsenter -t 1 -m --"
elif command -v nsenter >/dev/null 2>&1; then
    NSENTER="nsenter -t 1 -m --"
else
    NSENTER=""
fi
log_pfd "nsenter: ${NSENTER:-none}"

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
bind_over_dir() {
    src="$1"
    dest="$2"
    [ -d "$src" ] || return 1
    [ -d "$dest" ] || { log_pfd "bind-dir skip (no dest): $dest"; return 1; }
    chcon --reference="$dest" "$src" 2>/dev/null
    if [ -n "$NSENTER" ]; then
        $NSENTER umount -l "$dest" 2>/dev/null
        if $NSENTER mount --bind "$src" "$dest"; then
            log_pfd "bind-dir OK (init) $dest"
            return 0
        fi
    fi
    umount -l "$dest" 2>/dev/null
    if mount --bind "$src" "$dest"; then
        log_pfd "bind-dir OK (local) $dest"
        return 0
    fi
    log_pfd "bind-dir FAIL $src -> $dest"
    return 1
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
ns_umount() {
    dest="$1"
    [ -n "$NSENTER" ] && $NSENTER umount -l "$dest" 2>/dev/null
    umount -l "$dest" 2>/dev/null
}
busybox_bin() {
    for cand in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /data/adb/ap/bin/busybox; do
        [ -x "$cand" ] && { echo "$cand"; return 0; }
    done
    return 1
}
# Bind cannot create missing dest files. OverlayFS *can* add them if the
# module tree has tr_product/. Also inject audio into the zip for players
# that read audio.ogg / bootsound.ogg from bootanimation.zip itself.
try_inject_audio() {
    zipfile="$1"
    ogg="$2"
    [ -f "$zipfile" ] && [ -f "$ogg" ] || return 1
    tmpd="$MODDIR/.boot_inject"
    rm -rf "$tmpd"
    mkdir -p "$tmpd"
    cp "$ogg" "$tmpd/audio.ogg"
    cp "$ogg" "$tmpd/bootsound.ogg"
    BB=$(busybox_bin)
    if [ -z "$BB" ]; then
        log_pfd "zip inject skipped (no busybox): $zipfile"
        rm -rf "$tmpd"
        return 1
    fi
    if ( cd "$tmpd" && "$BB" zip -j -u "$zipfile" audio.ogg bootsound.ogg ); then
        log_pfd "injected audio.ogg into $zipfile"
        rm -rf "$tmpd"
        return 0
    fi
    log_pfd "zip inject FAIL $zipfile"
    rm -rf "$tmpd"
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

BS_ON=$(cfg_bool boot_sound true)
for f in \
    "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg" \
    "$MODDIR/product/media/audio/bootsound/Waltz.ogg" \
    "$MODDIR/system/media/audio/bootsound/Waltz.ogg" \
    "$MODDIR/system/media/audio/ui/Waltz.ogg"
do
    if [ "$BS_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done
# Live dests we may have bind-mounted last boot — drop them before re-applying
for dest in \
    /tr_product/media/bootanimation.zip \
    /tr_product/media/bootanimation-dark.zip \
    /tr_product/media/shutdownanimation.zip \
    /tr_product/media/audio/ui/PowerOn.ogg \
    /tr_product/media/audio/bootsound \
    /tr_product/media/audio/bootsound/Waltz.ogg \
    /product/media/bootanimation.zip \
    /system/product/media/bootanimation.zip \
    /system/media/bootanimation.zip \
    /oem/media/bootanimation.zip \
    /apex/com.android.bootanimation/etc/bootanimation.zip \
    /product/media/bootanimation-dark.zip \
    /system/product/media/bootanimation-dark.zip \
    /product/media/shutdownanimation.zip \
    /system/product/media/shutdownanimation.zip \
    /system/media/shutdownanimation.zip \
    /oem/media/shutdownanimation.zip \
    /product/media/audio/ui/PowerOn.ogg \
    /system/product/media/audio/ui/PowerOn.ogg \
    /system/media/audio/ui/PowerOn.ogg \
    /product/media/audio/bootsound \
    /system/product/media/audio/bootsound \
    /system/media/audio/bootsound
do
    ns_umount "$dest"
done
ns_umount /tr_product/media
ns_umount /product/media
ns_umount /system/product/media
ns_umount /system/media

CA_ON=$(cfg_bool charge_anim "$CA_DEF")
for f in "$MODDIR/system/product/theme/charge/hios_wire_charging_lockscreen.mp4" \
         "$MODDIR/system/product/theme/charge/lockscreen_charge_config.xml"; do
    if [ "$CA_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

FORCE_120HZ_STATE=$(cfg_bool force_120hz false)
APM_CONFIG_DIR="$MODDIR/system/product/apm/config"
APM_BYPASS_DIR="$MODDIR/system/product/apm/config_120hz_bypass"
for name in refresh_rate_config.json project_refresh_rate_config.json; do
    REAL="$APM_CONFIG_DIR/$name"
    BYPASS="$APM_BYPASS_DIR/$name"
    BACKUP="$APM_CONFIG_DIR/${name}.stock"
    if [ "$FORCE_120HZ_STATE" = "1" ]; then
        if [ -f "$BYPASS" ]; then
            if [ ! -f "$BACKUP" ]; then
                if [ -f "$REAL" ]; then
                    cp "$REAL" "$BACKUP"
                fi
            fi
            cp -f "$BYPASS" "$REAL"
            log_pfd "$name: force_120hz=1 -> bypass config applied"
        else
            log_pfd "$name: force_120hz=1 but bypass file missing: $BYPASS"
        fi
    else
        if [ -f "$BACKUP" ]; then
            cp -f "$BACKUP" "$REAL"
            log_pfd "$name: force_120hz=0 -> stock config restored"
        fi
    fi
done

# Magisk/Mountify rewrite system/product -> product, so the style zips are
# often at $MODDIR/product/theme/animations — not system/product/theme/...
# Skip empty dirs (Mountify leftover) so we do not hide zips still under system/product.
ANIM_DIR=""
for d in \
    "$MODDIR/product/theme/animations" \
    "$MODDIR/system/product/theme/animations" \
    "$MODDIR/tr_product/theme/animations" \
    "$MODDIR/system/tr_product/theme/animations" \
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
log_pfd "module bootanim_*.zip:"
find "$MODDIR" /mnt/vendor/mountify -name 'bootanim_*.zip' 2>/dev/null >> "$PFD_LOG"
log_pfd "live /tr_product/media:"
ls -la /tr_product/media >> "$PFD_LOG" 2>/dev/null
log_pfd "live /product/media:"
ls -la /product/media >> "$PFD_LOG" 2>/dev/null

MEDIA_DIRS="$MODDIR/tr_product/media $MODDIR/system/tr_product/media $MODDIR/product/media $MODDIR/system/product/media $MODDIR/system/media"

pick_style_zip() {
    kind="$1"
    style="$2"
    hit=""
    case "$style" in
        off)
            return 1
            ;;
        custom)
            if [ "$kind" = "bootanim" ]; then
                hit=$(first_existing \
                    "$MODDIR/product/media/bootanimation_custom.zip" \
                    "$MODDIR/system/product/media/bootanimation_custom.zip" \
                    "$MODDIR/system/media/bootanimation_custom.zip" \
                    "$MODDIR/tr_product/media/bootanimation_custom.zip")
            else
                hit=$(first_existing \
                    "$MODDIR/product/media/shutdownanimation_custom.zip" \
                    "$MODDIR/system/product/media/shutdownanimation_custom.zip" \
                    "$MODDIR/system/media/shutdownanimation_custom.zip" \
                    "$MODDIR/tr_product/media/shutdownanimation_custom.zip")
            fi
            ;;
        *)
            hit=$(first_existing \
                "$ANIM_DIR/${kind}_$style.zip" \
                "$MODDIR/product/theme/animations/${kind}_$style.zip" \
                "$MODDIR/system/product/theme/animations/${kind}_$style.zip" \
                "/mnt/vendor/mountify/product/theme/animations/${kind}_$style.zip" \
                "/mnt/vendor/mountify/system/product/theme/animations/${kind}_$style.zip")
            [ -n "$hit" ] || hit=$(find "$MODDIR" -name "${kind}_${style}.zip" 2>/dev/null | head -n 1)
            ;;
    esac
    [ -n "$hit" ] && echo "$hit"
}

stage_named() {
    src="$1"
    name="$2"
    [ -f "$src" ] || return 1
    for dir in $MEDIA_DIRS; do
        mkdir -p "$dir"
        dest="$dir/$name"
        [ "$src" = "$dest" ] && continue
        cp -f "$src" "$dest"
        chmod 644 "$dest" 2>/dev/null
    done
    return 0
}

# Copy live extras into a stage dir so bind-dir does not hide them.
mirror_live_media() {
    live="$1"
    stage="$2"
    [ -d "$live" ] || return 1
    mkdir -p "$stage"
    for f in "$live"/*; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        [ -e "$stage/$base" ] && continue
        cp -a "$f" "$stage/$base" 2>/dev/null
        log_pfd "mirrored live $live/$base"
    done
}

BA_STYLE=$(cfg_get bootanim_style "default")
SA_STYLE=$(cfg_get shutdownanim_style "default")

# Always start from a clean stage so we never re-inject audio into last boot's zip
for dir in $MEDIA_DIRS; do
    mkdir -p "$dir"
    rm -f "$dir/bootanimation.zip" "$dir/bootanimation-dark.zip" "$dir/shutdownanimation.zip"
    rm -f "$dir/audio.ogg" "$dir/bootsound.ogg"
done

SRC_BOOTANIM=""
if [ "$BA_STYLE" != "off" ]; then
    SRC_BOOTANIM=$(pick_style_zip bootanim "$BA_STYLE")
    if [ -z "$SRC_BOOTANIM" ] && [ "$BA_STYLE" = "custom" ]; then
        for dir in $MEDIA_DIRS "$MODDIR/product/media" "$MODDIR/system/product/media"; do
            for f in "$dir"/bootanimation_custom.*; do
                [ -f "$f" ] || continue
                SRC_BOOTANIM="$f"
                break
            done
            [ -n "$SRC_BOOTANIM" ] && break
        done
    fi
    if [ -n "$SRC_BOOTANIM" ]; then
        mkdir -p "$MODDIR/tr_product/media"
        cp -f "$SRC_BOOTANIM" "$MODDIR/tr_product/media/bootanimation.zip"
        chmod 644 "$MODDIR/tr_product/media/bootanimation.zip" 2>/dev/null
        log_pfd "bootanim staged from $SRC_BOOTANIM style=$BA_STYLE"
    else
        log_pfd "bootanim: no module zip to stage (style=$BA_STYLE)"
    fi
else
    log_pfd "bootanim: off — will not replace live zip"
fi

SRC_SHUTDOWN=""
if [ "$SA_STYLE" != "off" ]; then
    SRC_SHUTDOWN=$(pick_style_zip shutdownanim "$SA_STYLE")
    if [ -z "$SRC_SHUTDOWN" ] && [ "$SA_STYLE" = "custom" ]; then
        for dir in $MEDIA_DIRS; do
            for f in "$dir"/shutdownanimation_custom.*; do
                [ -f "$f" ] || continue
                SRC_SHUTDOWN="$f"
                break
            done
            [ -n "$SRC_SHUTDOWN" ] && break
        done
    fi
    if [ -n "$SRC_SHUTDOWN" ]; then
        stage_named "$SRC_SHUTDOWN" "shutdownanimation.zip"
        log_pfd "shutdownanim staged from $SRC_SHUTDOWN style=$SA_STYLE"
    fi
fi

SRC_BOOTSOUND=$(first_existing \
    "$MODDIR/product/media/audio/bootsound/Waltz.ogg" \
    "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg" \
    "$MODDIR/system/media/audio/bootsound/Waltz.ogg" \
    "$MODDIR/system/media/audio/ui/Waltz.ogg")

TRP_STAGE="$MODDIR/tr_product/media"
mkdir -p "$TRP_STAGE"

if [ "$BS_ON" = "1" ] && [ -n "$SRC_BOOTSOUND" ]; then
    log_pfd "bootsound src=$SRC_BOOTSOUND"
    mkdir -p "$TRP_STAGE/audio/ui" "$TRP_STAGE/audio/bootsound"
    mkdir -p "$MODDIR/product/media/audio/ui" "$MODDIR/product/media/audio/bootsound"
    mkdir -p "$MODDIR/system/product/media/audio/ui"
    mkdir -p "$MODDIR/system/tr_product/media/audio/ui" "$MODDIR/system/tr_product/media/audio/bootsound"
    cp -f "$SRC_BOOTSOUND" "$TRP_STAGE/audio/ui/PowerOn.ogg"
    cp -f "$SRC_BOOTSOUND" "$TRP_STAGE/audio/bootsound/Waltz.ogg"
    cp -f "$SRC_BOOTSOUND" "$TRP_STAGE/audio.ogg"
    cp -f "$SRC_BOOTSOUND" "$TRP_STAGE/bootsound.ogg"
    cp -f "$SRC_BOOTSOUND" "$MODDIR/system/tr_product/media/audio/ui/PowerOn.ogg"
    cp -f "$SRC_BOOTSOUND" "$MODDIR/system/tr_product/media/audio/bootsound/Waltz.ogg"
    cp -f "$SRC_BOOTSOUND" "$MODDIR/product/media/audio/ui/PowerOn.ogg"
    if [ "$BA_STYLE" != "off" ] && [ -f "$TRP_STAGE/bootanimation.zip" ]; then
        try_inject_audio "$TRP_STAGE/bootanimation.zip" "$SRC_BOOTSOUND"
    fi
elif [ "$BS_ON" = "1" ]; then
    log_pfd "bootsound: Waltz.ogg missing — nothing to stage"
else
    log_pfd "bootsound: off — left stock paths unbound"
fi

if [ -n "$SRC_BOOTANIM" ] && [ -f "$TRP_STAGE/bootanimation.zip" ]; then
    cp -f "$TRP_STAGE/bootanimation.zip" "$TRP_STAGE/bootanimation-dark.zip"
    stage_named "$TRP_STAGE/bootanimation.zip" "bootanimation.zip"
    stage_named "$TRP_STAGE/bootanimation.zip" "bootanimation-dark.zip"
fi

# Prefer bind-dir of /tr_product/media so we can ADD files (sound) that do not
# exist on the live partition. Mirror leftover live files first so we do not hide them.
TRP_DIR_BOUND=0
if [ -d /tr_product/media ]; then
    if [ "$BA_STYLE" != "off" ] || [ "$BS_ON" = "1" ]; then
        mirror_live_media /tr_product/media "$TRP_STAGE"
        if bind_over_dir "$TRP_STAGE" /tr_product/media; then
            TRP_DIR_BOUND=1
        fi
    fi
fi

STAGED_BOOT=$(first_existing \
    "$MODDIR/tr_product/media/bootanimation.zip" \
    "$MODDIR/product/media/bootanimation.zip" \
    "$MODDIR/system/product/media/bootanimation.zip" \
    "$MODDIR/system/media/bootanimation.zip")
STAGED_SHUT=$(first_existing \
    "$MODDIR/tr_product/media/shutdownanimation.zip" \
    "$MODDIR/product/media/shutdownanimation.zip" \
    "$MODDIR/system/product/media/shutdownanimation.zip" \
    "$MODDIR/system/media/shutdownanimation.zip")

if [ "$BA_STYLE" != "off" ] && [ -n "$SRC_BOOTANIM" ] && [ -n "$STAGED_BOOT" ]; then
    log_pfd "bootanim src=$STAGED_BOOT style=$BA_STYLE"
    if [ "$TRP_DIR_BOUND" != "1" ]; then
        try_bind_file "$STAGED_BOOT" /tr_product/media/bootanimation.zip
        try_bind_file "$STAGED_BOOT" /tr_product/media/bootanimation-dark.zip
    fi
    try_bind_file "$STAGED_BOOT" /product/media/bootanimation.zip
    try_bind_file "$STAGED_BOOT" /system/product/media/bootanimation.zip
    try_bind_file "$STAGED_BOOT" /system/media/bootanimation.zip
    try_bind_file "$STAGED_BOOT" /oem/media/bootanimation.zip
    try_bind_file "$STAGED_BOOT" /apex/com.android.bootanimation/etc/bootanimation.zip
    for dest in $(find_named bootanimation.zip) $(find_named bootanimation-dark.zip); do
        if [ "$TRP_DIR_BOUND" = "1" ]; then
            case "$dest" in
                /tr_product/*) continue ;;
            esac
        fi
        try_bind_file "$STAGED_BOOT" "$dest"
    done
elif [ "$BA_STYLE" != "off" ]; then
    log_pfd "bootanim: no module zip to bind (style=$BA_STYLE)"
fi

if [ "$SA_STYLE" != "off" ] && [ -n "$SRC_SHUTDOWN" ] && [ -n "$STAGED_SHUT" ]; then
    log_pfd "shutdownanim src=$STAGED_SHUT style=$SA_STYLE"
    if [ "$TRP_DIR_BOUND" != "1" ]; then
        try_bind_file "$STAGED_SHUT" /tr_product/media/shutdownanimation.zip
    fi
    try_bind_file "$STAGED_SHUT" /product/media/shutdownanimation.zip
    try_bind_file "$STAGED_SHUT" /system/product/media/shutdownanimation.zip
    try_bind_file "$STAGED_SHUT" /system/media/shutdownanimation.zip
    try_bind_file "$STAGED_SHUT" /oem/media/shutdownanimation.zip
    for dest in $(find_named shutdownanimation.zip); do
        if [ "$TRP_DIR_BOUND" = "1" ]; then
            case "$dest" in
                /tr_product/*) continue ;;
            esac
        fi
        try_bind_file "$STAGED_SHUT" "$dest"
    done
fi

if [ "$BS_ON" = "1" ] && [ -n "$SRC_BOOTSOUND" ]; then
    SRC_BOOTSOUND_DIR=""
    for d in \
        "$MODDIR/tr_product/media/audio/bootsound" \
        "$MODDIR/product/media/audio/bootsound" \
        "$MODDIR/system/product/media/audio/bootsound" \
        "$MODDIR/system/media/audio/bootsound"
    do
        [ -d "$d" ] && [ -f "$d/Waltz.ogg" ] && SRC_BOOTSOUND_DIR="$d" && break
    done
    for dest in \
        /tr_product/media/audio/ui/PowerOn.ogg \
        /tr_product/media/audio/bootsound/Waltz.ogg \
        /tr_product/media/audio.ogg \
        /tr_product/media/bootsound.ogg \
        /product/media/audio/ui/PowerOn.ogg \
        /system/product/media/audio/ui/PowerOn.ogg \
        /system/media/audio/ui/PowerOn.ogg \
        /system/media/bootsound.ogg \
        /system/media/bootsound.mp3 \
        /system/media/audio/bootaudio.mp3
    do
        try_bind_file "$SRC_BOOTSOUND" "$dest"
    done
    for dir in \
        /tr_product/media/audio/bootsound \
        /product/media/audio/bootsound \
        /system/product/media/audio/bootsound \
        /system/media/audio/bootsound
    do
        if [ -n "$SRC_BOOTSOUND_DIR" ] && bind_over_dir "$SRC_BOOTSOUND_DIR" "$dir"; then
            :
        elif [ -d "$dir" ]; then
            for f in "$dir"/*; do
                [ -f "$f" ] || continue
                try_bind_file "$SRC_BOOTSOUND" "$f"
            done
        fi
    done
fi

EF_ON=$(cfg_bool emoji_font true)
for f in "$MODDIR/system/fonts/NotoColorEmoji.ttf" "$MODDIR/system/product/fonts/NotoColorEmoji.ttf"; do
    if [ "$EF_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

SOUNDS_DIR="$MODDIR/system/product/theme/sounds/charging"
CS_STYLE=$(cfg_get chargesound_style "default")
for dir in "$MODDIR/system/product/media/audio/ui" "$MODDIR/system/media/audio/ui"; do
    mkdir -p "$dir"
    for DEST in "$dir/ChargingStarted.ogg" "$dir/charging_sound.ogg"; do
        case "$CS_STYLE" in
            off)
                rm -f "$DEST"
                ;;
            custom)
                for f in "$dir"/ChargingStarted_custom.*; do
                    [ -e "$f" ] || continue
                    rm -f "$DEST"
                    cp "$f" "$DEST"
                    break
                done
                ;;
            default|huawei|ios|s25)
                [ -f "$SOUNDS_DIR/$CS_STYLE.ogg" ] && cp "$SOUNDS_DIR/$CS_STYLE.ogg" "$DEST"
                ;;
        esac
    done
done

WS_STYLE=$(cfg_get wirelesschargesound_style "default")
for dir in "$MODDIR/system/product/media/audio/ui" "$MODDIR/system/media/audio/ui"; do
    DEST="$dir/WirelessChargingStarted.ogg"
    mkdir -p "$dir"
    case "$WS_STYLE" in
        off)
            rm -f "$DEST"
            ;;
        custom)
            for f in "$dir"/WirelessChargingStarted_custom.*; do
                [ -e "$f" ] || continue
                rm -f "$DEST"
                cp "$f" "$DEST"
                break
            done
            ;;
        default|huawei|ios|s25)
            [ -f "$SOUNDS_DIR/$WS_STYLE.ogg" ] && cp "$SOUNDS_DIR/$WS_STYLE.ogg" "$DEST"
            ;;
    esac
done

SYS_SOUNDS_DIR="$MODDIR/system/product/theme/sounds/system"
SYS_SOUND_NAMES="Calculagraph Cobalt Disconnect Dock Effect_Tick Fail Gear InCallNotification KeypressDelete KeypressInvalid KeypressReturn KeypressSpacebar KeypressStandard Lock Screenshots Second_Hand Sent_Success Success Trusted Undock Unlock beep_once beep_twice delete sent_message_success"
for dir in "$MODDIR/system/product/media/audio/ui" "$MODDIR/system/media/audio/ui"; do
    mkdir -p "$dir"
    for name in $SYS_SOUND_NAMES; do
        DEST="$dir/${name}.ogg"
        STYLE=$(cfg_get "sound_${name}_style" "off")
        MARKER="$dir/.tf_wrote_${name}"
        case "$STYLE" in
            pack)
                if [ -f "$SYS_SOUNDS_DIR/${name}.ogg" ]; then
                    rm -f "$DEST"
                    cp "$SYS_SOUNDS_DIR/${name}.ogg" "$DEST"
                    chmod 644 "$DEST" 2>/dev/null
                    chcon --reference="$SYS_SOUNDS_DIR/${name}.ogg" "$DEST" 2>/dev/null
                    : > "$MARKER"
                    log_pfd "$name [$dir]: style=pack -> copied ($([ -f "$DEST" ] && echo OK || echo FAILED)), perms=$(ls -lZ "$DEST" 2>/dev/null | awk '{print $1, $(NF-1)}')"
                else
                    log_pfd "$name [$dir]: style=pack but pack source missing: $SYS_SOUNDS_DIR/${name}.ogg"
                fi
                ;;
            custom)
                FOUND=""
                for f in "$dir/${name}_custom".*; do
                    [ -e "$f" ] || continue
                    FOUND="$f"
                    rm -f "$DEST"
                    cp "$f" "$DEST"
                    chmod 644 "$DEST" 2>/dev/null
                    chcon --reference="$SYS_SOUNDS_DIR/${name}.ogg" "$DEST" 2>/dev/null
                    : > "$MARKER"
                    break
                done
                if [ -n "$FOUND" ]; then
                    log_pfd "$name [$dir]: style=custom, source=$FOUND -> copied ($([ -f "$DEST" ] && echo OK || echo FAILED))"
                else
                    log_pfd "$name [$dir]: style=custom but NO matching ${name}_custom.* file found in $dir"
                fi
                ;;
            off)
                if [ -f "$MARKER" ]; then
                    rm -f "$DEST" "$MARKER"
                    log_pfd "$name [$dir]: style=off -> removed our override, stock restored"
                fi
                ;;
        esac
    done
done

SB_STYLE=$(cfg_get statusbar_style "$SB_DEF")
IOS_APK_A="$MODDIR/system/overlay/Icons_Signal_wifi/Icons_Signal_wifi.apk"
IOS_APK_B="$MODDIR/system/product/overlay/Icons_Signal_wifi/Icons_Signal_wifi.apk"
XOS16_APK_A="$MODDIR/system/overlay/SystemUISignalOverlay.apk"
XOS16_APK_B="$MODDIR/system/product/overlay/SystemUISignalOverlay.apk"
CUSTOM_APK_A="$MODDIR/system/overlay/Icons_Signal_wifi_custom.apk"
CUSTOM_APK_B="$MODDIR/system/product/overlay/Icons_Signal_wifi_custom.apk"

case "$SB_STYLE" in
    ios)
        [ -f "${IOS_APK_A}.disabled" ] && mv "${IOS_APK_A}.disabled" "$IOS_APK_A"
        [ -f "${IOS_APK_B}.disabled" ] && mv "${IOS_APK_B}.disabled" "$IOS_APK_B"
        [ -f "$XOS16_APK_A" ] && mv "$XOS16_APK_A" "${XOS16_APK_A}.disabled"
        [ -f "$XOS16_APK_B" ] && mv "$XOS16_APK_B" "${XOS16_APK_B}.disabled"
        [ -f "$CUSTOM_APK_A" ] && mv "$CUSTOM_APK_A" "${CUSTOM_APK_A}.disabled"
        [ -f "$CUSTOM_APK_B" ] && mv "$CUSTOM_APK_B" "${CUSTOM_APK_B}.disabled"
        ;;
    xos16)
        [ -f "$IOS_APK_A" ] && mv "$IOS_APK_A" "${IOS_APK_A}.disabled"
        [ -f "$IOS_APK_B" ] && mv "$IOS_APK_B" "${IOS_APK_B}.disabled"
        [ -f "${XOS16_APK_A}.disabled" ] && mv "${XOS16_APK_A}.disabled" "$XOS16_APK_A"
        [ -f "${XOS16_APK_B}.disabled" ] && mv "${XOS16_APK_B}.disabled" "$XOS16_APK_B"
        [ -f "$CUSTOM_APK_A" ] && mv "$CUSTOM_APK_A" "${CUSTOM_APK_A}.disabled"
        [ -f "$CUSTOM_APK_B" ] && mv "$CUSTOM_APK_B" "${CUSTOM_APK_B}.disabled"
        ;;
    custom)
        [ -f "$IOS_APK_A" ] && mv "$IOS_APK_A" "${IOS_APK_A}.disabled"
        [ -f "$IOS_APK_B" ] && mv "$IOS_APK_B" "${IOS_APK_B}.disabled"
        [ -f "$XOS16_APK_A" ] && mv "$XOS16_APK_A" "${XOS16_APK_A}.disabled"
        [ -f "$XOS16_APK_B" ] && mv "$XOS16_APK_B" "${XOS16_APK_B}.disabled"
        [ -f "${CUSTOM_APK_A}.disabled" ] && mv "${CUSTOM_APK_A}.disabled" "$CUSTOM_APK_A"
        [ -f "${CUSTOM_APK_B}.disabled" ] && mv "${CUSTOM_APK_B}.disabled" "$CUSTOM_APK_B"
        ;;
    off)
        [ -f "$IOS_APK_A" ] && mv "$IOS_APK_A" "${IOS_APK_A}.disabled"
        [ -f "$IOS_APK_B" ] && mv "$IOS_APK_B" "${IOS_APK_B}.disabled"
        [ -f "$XOS16_APK_A" ] && mv "$XOS16_APK_A" "${XOS16_APK_A}.disabled"
        [ -f "$XOS16_APK_B" ] && mv "$XOS16_APK_B" "${XOS16_APK_B}.disabled"
        [ -f "$CUSTOM_APK_A" ] && mv "$CUSTOM_APK_A" "${CUSTOM_APK_A}.disabled"
        [ -f "$CUSTOM_APK_B" ] && mv "$CUSTOM_APK_B" "${CUSTOM_APK_B}.disabled"
        ;;
esac

FOD_ON=$(cfg_bool fod_animation "$FOD_DEF")
FOD_RES_A="$MODDIR/system/product/overlay/FodResOverlay/FodResOverlay.apk"
FOD_RES_B="$MODDIR/system/overlay/FodResOverlay/FodResOverlay.apk"
FOD_SET_A="$MODDIR/system/product/overlay/FodSetOverlay/FodSetOverlay.apk"
FOD_SET_B="$MODDIR/system/overlay/FodSetOverlay/FodSetOverlay.apk"
for f in "$FOD_RES_A" "$FOD_RES_B" "$FOD_SET_A" "$FOD_SET_B"; do
    if [ "$FOD_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

for part in /cache /system /vendor /data /product /metadata /odm /data/dalvik-cache; do
  [ -d "$part" ] && fstrim -v "$part" > /dev/null 2>&1
done
[ -d /preload ] && fstrim -v /preload > /dev/null 2>&1
