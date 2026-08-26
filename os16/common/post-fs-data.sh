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

busybox_bin() {
    for cand in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /data/adb/ap/bin/busybox; do
        [ -x "$cand" ] && { echo "$cand"; return 0; }
    done
    return 1
}

# Recursively copy live extras into stage so a bind-dir does not hide them.
# Files already in stage (our overrides) win.
merge_tree() {
    live="$1"
    stage="$2"
    [ -d "$live" ] || return 1
    mkdir -p "$stage"
    for f in "$live"/*; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        if [ -d "$f" ]; then
            merge_tree "$f" "$stage/$base"
        elif [ ! -e "$stage/$base" ]; then
            cp -a "$f" "$stage/$base" 2>/dev/null
        fi
    done
}

# AOSP bootanim plays audio.wav from inside the zip. Transsion may also look for audio.ogg.
try_inject_audio() {
    zipfile="$1"
    ogg="$2"
    wav="$3"
    [ -f "$zipfile" ] || return 1
    tmpd="$MODDIR/.boot_inject"
    rm -rf "$tmpd"
    mkdir -p "$tmpd"
    names=""
    if [ -f "$wav" ]; then
        cp "$wav" "$tmpd/audio.wav"
        names="$names audio.wav"
    fi
    if [ -f "$ogg" ]; then
        cp "$ogg" "$tmpd/audio.ogg"
        cp "$ogg" "$tmpd/bootsound.ogg"
        names="$names audio.ogg bootsound.ogg"
    fi
    [ -n "$names" ] || { rm -rf "$tmpd"; return 1; }
    BB=$(busybox_bin)
    ZIPBIN=""
    if [ -n "$BB" ]; then
        ZIPBIN="$BB zip"
    elif command -v zip >/dev/null 2>&1; then
        ZIPBIN="zip"
    fi
    if [ -z "$ZIPBIN" ]; then
        log_pfd "zip inject skipped (no busybox/zip): $zipfile"
        rm -rf "$tmpd"
        return 1
    fi
    # shellcheck disable=SC2086
    if ( cd "$tmpd" && $ZIPBIN -j -u "$zipfile" $names ); then
        log_pfd "injected $names into $zipfile"
        rm -rf "$tmpd"
        return 0
    fi
    log_pfd "zip inject FAIL $zipfile"
    rm -rf "$tmpd"
    return 1
}

for dest in \
    /tr_product/media/bootanimation.zip \
    /tr_product/media/bootanimation-dark.zip \
    /tr_product/media/audio/ui/PowerOn.ogg \
    /tr_product/media/audio/ui/PowerOn.wav \
    /tr_product/media/audio/bootsound \
    /tr_product/media/audio/bootsound/Waltz.ogg \
    /tr_product/media/audio \
    /product/media/bootanimation.zip \
    /system/product/media/bootanimation.zip \
    /system/media/bootanimation.zip \
    /oem/media/bootanimation.zip \
    /apex/com.android.bootanimation/etc/bootanimation.zip \
    /product/media/audio/ui/PowerOn.ogg \
    /system/product/media/audio/ui/PowerOn.ogg \
    /system/media/audio/ui/PowerOn.ogg \
    /product/media/audio/bootsound \
    /system/product/media/audio/bootsound \
    /system/media/audio/bootsound
do
    ns_umount "$dest"
done
# Undo Flagship 15 whole-dir bind if it was left mounted
ns_umount /tr_product/media

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
log_pfd "live /tr_product/media/audio:"
ls -la /tr_product/media/audio >> "$PFD_LOG" 2>/dev/null
log_pfd "live audio tree:"
ls -laR /tr_product/media/audio >> "$PFD_LOG" 2>/dev/null
log_pfd "named boot-sound files:"
find /tr_product /product /system /system_ext /oem -maxdepth 6 \
    \( -iname 'PowerOn.ogg' -o -iname 'PowerOn.wav' -o -iname 'Waltz.ogg' -o -iname 'Waltz.wav' \
       -o -iname 'bootsound.ogg' -o -iname 'bootsound.mp3' -o -iname 'bootaudio.mp3' \
       -o -iname 'audio.wav' -o -iname 'audio.ogg' \) 2>/dev/null >> "$PFD_LOG"
if [ -f /tr_product/media/bootanimation.zip ]; then
    log_pfd "stock zip audio members:"
    listed=""
    if unzip -l /tr_product/media/bootanimation.zip >/dev/null 2>&1; then
        unzip -l /tr_product/media/bootanimation.zip 2>/dev/null | grep -iE 'audio|\.ogg|\.wav|boot' >> "$PFD_LOG"
        listed=1
    fi
    if [ -z "$listed" ]; then
        BB=$(busybox_bin)
        if [ -n "$BB" ]; then
            $BB unzip -l /tr_product/media/bootanimation.zip 2>/dev/null | grep -iE 'audio|\.ogg|\.wav|boot' >> "$PFD_LOG"
        fi
    fi
fi

BA_STYLE=$(cfg_get bootanim_style "hios16")
BS=$(cfg_get boot_sound "waltz")
[ "$BS" = "true" ] && BS=waltz
[ "$BS" = "false" ] && BS=off
log_pfd "bootanim_style=$BA_STYLE boot_sound=$BS"

pick_boot_zip() {
    style="$1"
    hit=""
    case "$style" in
        off) return 1 ;;
        custom)
            hit=$(first_existing \
                "$MODDIR/tr_product/media/bootanimation_custom.zip" \
                "$MODDIR/product/media/bootanimation_custom.zip" \
                "$MODDIR/system/product/media/bootanimation_custom.zip" \
                "$MODDIR/system/media/bootanimation_custom.zip")
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

TRP_STAGE="$MODDIR/tr_product/media"
mkdir -p "$TRP_STAGE"
rm -f "$TRP_STAGE/bootanimation.zip" "$TRP_STAGE/bootanimation-dark.zip"

SRC=""
if [ "$BA_STYLE" = "off" ]; then
    log_pfd "bootanim: off — stock zip unless boot sound needs inject"
    if [ "$BS" != "off" ] && [ -f /tr_product/media/bootanimation.zip ]; then
        cp -f /tr_product/media/bootanimation.zip "$TRP_STAGE/bootanimation.zip"
        SRC="$TRP_STAGE/bootanimation.zip"
        log_pfd "bootanim: copied live zip for sound inject"
    fi
else
    SRC=$(pick_boot_zip "$BA_STYLE")
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

STAGED="$TRP_STAGE/bootanimation.zip"

SRC_BOOTSOUND=""
SRC_BOOTWAV=""
if [ "$BS" = "custom" ]; then
    SRC_BOOTSOUND=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.ogg" \
        "$MODDIR/product/media/audio/bootsound/custom.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/custom.ogg")
    SRC_BOOTWAV=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.wav" \
        "$MODDIR/product/media/audio/bootsound/custom.wav" \
        "$MODDIR/system/product/media/audio/bootsound/custom.wav")
elif [ "$BS" != "off" ]; then
    SRC_BOOTSOUND=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/media/audio/ui/Waltz.ogg")
    SRC_BOOTWAV=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz.wav" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.wav")
fi
log_pfd "bootsound ogg=${SRC_BOOTSOUND:-none} wav=${SRC_BOOTWAV:-none}"

if [ "$BS" != "off" ] && { [ -n "$SRC_BOOTSOUND" ] || [ -n "$SRC_BOOTWAV" ]; }; then
    mkdir -p "$TRP_STAGE/audio/ui" "$TRP_STAGE/audio/bootsound"
    merge_tree /tr_product/media/audio "$TRP_STAGE/audio"
    log_pfd "staged audio after merge:"
    ls -la "$TRP_STAGE/audio" >> "$PFD_LOG" 2>/dev/null
    if [ -n "$SRC_BOOTSOUND" ]; then
        cp -f "$SRC_BOOTSOUND" "$TRP_STAGE/audio/ui/PowerOn.ogg"
        cp -f "$SRC_BOOTSOUND" "$TRP_STAGE/audio/bootsound/Waltz.ogg"
    fi
    if [ -n "$SRC_BOOTWAV" ]; then
        cp -f "$SRC_BOOTWAV" "$TRP_STAGE/audio/ui/PowerOn.wav"
        cp -f "$SRC_BOOTWAV" "$TRP_STAGE/audio/bootsound/Waltz.wav"
    fi
    if [ -f "$STAGED" ]; then
        try_inject_audio "$STAGED" "$SRC_BOOTSOUND" "$SRC_BOOTWAV"
    else
        log_pfd "bootsound: no staged zip to inject into"
    fi
elif [ "$BS" = "off" ]; then
    log_pfd "bootsound: off — stock audio left unbound"
else
    log_pfd "bootsound: no ogg/wav to stage"
fi

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

if [ "$BS" != "off" ] && { [ -n "$SRC_BOOTSOUND" ] || [ -n "$SRC_BOOTWAV" ]; }; then
    AUDIO_STAGE="$TRP_STAGE/audio"
    if [ -d /tr_product/media/audio ]; then
        bind_over_dir "$AUDIO_STAGE" /tr_product/media/audio
    fi
    if [ -n "$SRC_BOOTSOUND" ]; then
        for dest in \
            /tr_product/media/audio/ui/PowerOn.ogg \
            /tr_product/media/audio/bootsound/Waltz.ogg \
            /product/media/audio/ui/PowerOn.ogg \
            /system/product/media/audio/ui/PowerOn.ogg \
            /system/media/audio/ui/PowerOn.ogg \
            /system/media/bootsound.ogg \
            /system/media/bootsound.mp3 \
            /system/media/audio/bootaudio.mp3
        do
            try_bind_file "$SRC_BOOTSOUND" "$dest"
        done
    fi
    if [ -n "$SRC_BOOTWAV" ]; then
        try_bind_file "$SRC_BOOTWAV" /tr_product/media/audio/ui/PowerOn.wav
        try_bind_file "$SRC_BOOTWAV" /tr_product/media/audio/bootsound/Waltz.wav
    fi
    log_pfd "bootsound bind pass done"
fi
