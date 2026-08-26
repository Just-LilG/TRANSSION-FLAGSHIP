#!/system/bin/sh

MODDIR=${0%/*}
CFG="$MODDIR/config.json"
PFD_LOG="$MODDIR/post_fs_data.log"
rm -f "$PFD_LOG"
rm -rf "$MODDIR/.bootanim_restart.lock" "$MODDIR/.bootanim_restarted" "$MODDIR/.boot_play.wav"
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

# X6886 libbootanimation.so initAudioPath() checks these in order (boot):
#   /product/media/audio/bootsound/Waltz.ogg
#   /tr_product/media/audio/bootsound/bootaudio.ogg
#   /data/local/bootaudio.mp3
# Stock ships none of them. Zip audio.wav is AOSP leftover and is ignored.
ensure_parent() {
    dest="$1"
    parent=$(dirname "$dest")
    mkdir -p "$parent" 2>/dev/null
    [ -n "$NSENTER" ] && $NSENTER mkdir -p "$parent" 2>/dev/null
}

place_boot_audio() {
    src="$1"
    dest="$2"
    [ -f "$src" ] || { log_pfd "place skip (no src) $dest"; return 1; }
    ensure_parent "$dest"
    case "$dest" in
        /tr_product/*)
            rel=${dest#/tr_product/}
            mkdir -p "$MODDIR/tr_product/$(dirname "$rel")"
            cp -f "$src" "$MODDIR/tr_product/$rel"
            chmod 644 "$MODDIR/tr_product/$rel" 2>/dev/null
            if [ -d /mnt/vendor/mountify/tr_product ]; then
                mkdir -p "/mnt/vendor/mountify/tr_product/$(dirname "$rel")"
                cp -f "$src" "/mnt/vendor/mountify/tr_product/$rel"
                chmod 644 "/mnt/vendor/mountify/tr_product/$rel" 2>/dev/null
                log_pfd "mountify $rel"
            fi
            ;;
        /product/*)
            rel=${dest#/product/}
            mkdir -p "$MODDIR/product/$(dirname "$rel")" \
                     "$MODDIR/system/product/$(dirname "$rel")"
            cp -f "$src" "$MODDIR/product/$rel"
            cp -f "$src" "$MODDIR/system/product/$rel"
            chmod 644 "$MODDIR/product/$rel" "$MODDIR/system/product/$rel" 2>/dev/null
            ;;
        /data/local/*)
            cp -f "$src" "$dest"
            chmod 644 "$dest" 2>/dev/null
            restorecon "$dest" 2>/dev/null
            log_pfd "copied $dest $(ls -l "$dest" 2>/dev/null)"
            return 0
            ;;
    esac
    if [ ! -e "$dest" ]; then
        touch "$dest" 2>/dev/null \
            || { [ -n "$NSENTER" ] && $NSENTER touch "$dest" 2>/dev/null; }
        [ -e "$dest" ] && log_pfd "created dest $dest"
    fi
    bind_over_file "$src" "$dest"
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

file_md5() {
    f="$1"
    [ -f "$f" ] || return 1
    sum=""
    if command -v md5sum >/dev/null 2>&1; then
        sum=$(md5sum "$f" 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$sum" ]; then
        BB=$(busybox_bin)
        [ -n "$BB" ] && sum=$($BB md5sum "$f" 2>/dev/null | awk '{print $1}')
    fi
    [ -n "$sum" ] && echo "$sum"
}

ensure_dir() {
    dest="$1"
    [ -d "$dest" ] && return 0
    mkdir -p "$dest" 2>/dev/null
    [ -n "$NSENTER" ] && $NSENTER mkdir -p "$dest" 2>/dev/null
    [ -d "$dest" ]
}

patch_charge_xml() {
    xml="$1"
    respath="$2"
    fname="$3"
    md5="$4"
    [ -f "$xml" ] || return 1
    sed -i "s|<resourcePath>[^<]*</resourcePath>|<resourcePath>${respath}</resourcePath>|g" "$xml"
    sed -i "s|<fileName>[^<]*</fileName>|<fileName>${fname}</fileName>|g" "$xml"
    sed -i "s|<fileMd5>[^<]*</fileMd5>|<fileMd5>${md5}</fileMd5>|g" "$xml"
}

# Stage xml + pngs + the chosen mp4. Never bind-dir /tr_product or /tr_product/theme.
stage_charge_tree() {
    dest="$1"
    respath="$2"
    pack="$3"
    src_mp4="$4"
    fname="$5"
    md5="$6"
    [ -d "$pack" ] || return 1
    [ -f "$src_mp4" ] || return 1
    mkdir -p "$dest"
    rm -f "$dest"/*.mp4 "$dest"/*.png "$dest"/*.xml
    for f in "$pack"/*.png "$pack"/lockscreen_charge_config.xml; do
        [ -f "$f" ] || continue
        cp -f "$f" "$dest/"
    done
    cp -f "$src_mp4" "$dest/$fname"
    chmod 644 "$dest"/* 2>/dev/null
    patch_charge_xml "$dest/lockscreen_charge_config.xml" "$respath" "$fname" "$md5"
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

zip_bin() {
    BB=$(busybox_bin)
    if [ -n "$BB" ]; then
        echo "$BB zip"
        return 0
    fi
    if command -v zip >/dev/null 2>&1; then
        echo zip
        return 0
    fi
    return 1
}

unzip_p() {
    zipfile="$1"
    member="$2"
    if command -v unzip >/dev/null 2>&1; then
        unzip -p "$zipfile" "$member" 2>/dev/null && return 0
    fi
    BB=$(busybox_bin)
    [ -n "$BB" ] && $BB unzip -p "$zipfile" "$member" 2>/dev/null
}

bootanim_part() {
    zipfile="$1"
    desc=$(unzip_p "$zipfile" desc.txt | tr -d '\r')
    part=$(printf '%s\n' "$desc" | awk 'NR>1 && ($1=="p"||$1=="c") && ($2+0)>0 {print $4; exit}')
    [ -z "$part" ] && part=$(printf '%s\n' "$desc" | awk 'NR>1 && ($1=="p"||$1=="c") {print $4; exit}')
    [ -n "$part" ] && echo "$part"
}

strip_zip_audio() {
    zipfile="$1"
    [ -f "$zipfile" ] || return 1
    part=$(bootanim_part "$zipfile")
    [ -n "$part" ] || return 1
    ZIPBIN=$(zip_bin)
    [ -n "$ZIPBIN" ] || return 1
    if $ZIPBIN -d "$zipfile" "$part/audio.wav" >/dev/null 2>&1; then
        log_pfd "stripped $part/audio.wav from $zipfile"
        return 0
    fi
    return 1
}

set_play_sound() {
    val="$1"
    if command -v resetprop >/dev/null 2>&1; then
        resetprop -n persist.sys.bootanim.play_sound "$val" 2>/dev/null \
            || resetprop persist.sys.bootanim.play_sound "$val" 2>/dev/null
        resetprop -n persist.sys.media.bootanim.play_sound "$val" 2>/dev/null
    elif [ -x /data/adb/magisk/resetprop ]; then
        /data/adb/magisk/resetprop -n persist.sys.bootanim.play_sound "$val" 2>/dev/null
        /data/adb/magisk/resetprop -n persist.sys.media.bootanim.play_sound "$val" 2>/dev/null
    elif [ -x /data/adb/ksu/bin/resetprop ]; then
        /data/adb/ksu/bin/resetprop -n persist.sys.bootanim.play_sound "$val" 2>/dev/null
        /data/adb/ksu/bin/resetprop -n persist.sys.media.bootanim.play_sound "$val" 2>/dev/null
    fi
    log_pfd "persist.sys.bootanim.play_sound=$val live=$(getprop persist.sys.bootanim.play_sound 2>/dev/null)"
}

convert_ogg_to_wav() {
    ogg="$1"
    wav="$2"
    [ -f "$ogg" ] || return 1
    TERMUX=/data/data/com.termux/files/usr
    for ff in \
        "$TERMUX/bin/ffmpeg" \
        /system/bin/ffmpeg /vendor/bin/ffmpeg /system_ext/bin/ffmpeg
    do
        [ -x "$ff" ] || continue
        if [ "$ff" = "$TERMUX/bin/ffmpeg" ]; then
            ok=$(LD_LIBRARY_PATH="$TERMUX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
                PATH="$TERMUX/bin:$PATH" \
                "$ff" -y -i "$ogg" -acodec pcm_s16le -ac 2 -ar 48000 "$wav" >/dev/null 2>&1 && echo yes)
        else
            ok=$("$ff" -y -i "$ogg" -acodec pcm_s16le -ac 2 -ar 48000 "$wav" >/dev/null 2>&1 && echo yes)
        fi
        if [ "$ok" = "yes" ]; then
            log_pfd "converted ogg->wav with $ff"
            return 0
        fi
        log_pfd "ffmpeg failed: $ff"
    done
    return 1
}

log_bootanim_bin() {
    log_pfd "bootanimation binaries:"
    ls -l /system/bin/bootanimation /apex/com.android.bootanimation/bin/bootanimation 2>>"$PFD_LOG"
    for b in /system/bin/bootanimation /apex/com.android.bootanimation/bin/bootanimation; do
        [ -f "$b" ] || continue
        log_pfd "strings audio in $b:"
        strings "$b" 2>/dev/null | grep -iE 'audio\.wav|play_sound|TinyALSA|audioplay' | head -n 20 >>"$PFD_LOG"
    done
}

# AOSP plays audio.wav from the *part folder* (part1/audio.wav), not zip root.
# zip -j put the file at the root, which bootanimation ignores.
try_inject_audio() {
    zipfile="$1"
    wav="$2"
    [ -f "$zipfile" ] || return 1
    [ -f "$wav" ] || { log_pfd "inject skip (no wav)"; return 1; }
    part=$(bootanim_part "$zipfile")
    [ -n "$part" ] || part="part1"
    log_pfd "inject into $part/audio.wav"
    tmpd="$MODDIR/.boot_inject"
    rm -rf "$tmpd"
    mkdir -p "$tmpd/$part"
    cp "$wav" "$tmpd/$part/audio.wav"
    ZIPBIN=$(zip_bin)
    if [ -n "$ZIPBIN" ]; then
        if ( cd "$tmpd" && $ZIPBIN -0 -u "$zipfile" "$part/audio.wav" ); then
            log_pfd "injected $part/audio.wav (store) into $zipfile"
            rm -rf "$tmpd"
            return 0
        fi
        log_pfd "zip -0 -u FAIL, rebuilding zip"
        work="$MODDIR/.boot_rebuild"
        rm -rf "$work"
        mkdir -p "$work"
        if command -v unzip >/dev/null 2>&1; then
            unzip -o "$zipfile" -d "$work" >/dev/null 2>&1
        else
            BB=$(busybox_bin)
            [ -n "$BB" ] && $BB unzip -o "$zipfile" -d "$work" >/dev/null 2>&1
        fi
        mkdir -p "$work/$part"
        cp "$wav" "$work/$part/audio.wav"
        out="$MODDIR/.boot_repacked.zip"
        rm -f "$out"
        if ( cd "$work" && $ZIPBIN -0 -r "$out" . ); then
            mv "$out" "$zipfile"
            log_pfd "rebuilt zip with $part/audio.wav"
            rm -rf "$tmpd" "$work"
            return 0
        fi
        log_pfd "zip rebuild FAIL"
        rm -rf "$tmpd" "$work"
        return 1
    fi
    log_pfd "zip inject skipped (no zip binary)"
    rm -rf "$tmpd"
    return 1
}

for dest in \
    /tr_product/media/bootanimation.zip \
    /tr_product/media/bootanimation-dark.zip \
    /tr_product/media/audio/ui/PowerOn.ogg \
    /tr_product/media/audio/ui/PowerOn.wav \
    /tr_product/media/audio/bootsound \
    /tr_product/media/audio/bootsound/bootaudio.ogg \
    /tr_product/media/audio/bootsound/Waltz.ogg \
    /product/media/audio/bootsound/Waltz.ogg \
    /product/media/audio/bootsound/bootaudio.ogg \
    /tr_product/media/audio \
    /tr_product/media/bootsound.ogg \
    /tr_product/media/bootsound.mp3 \
    /tr_product/media/audio.ogg \
    /tr_product/media/audio.mp3 \
    /tr_product/media/bootsound.wav \
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
    /system/media/userspace-reboot.zip \
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
RA_STYLE=$(cfg_get rebootanim_style "hios16")
[ -z "$RA_STYLE" ] && RA_STYLE=$(cfg_get shutdownanim_style "hios16")
CA_STYLE=$(cfg_get chargeanim_style "hios16")
BS=$(cfg_get boot_sound "waltz")
[ "$BS" = "true" ] && BS=waltz
[ "$BS" = "false" ] && BS=off
log_pfd "bootanim_style=$BA_STYLE rebootanim_style=$RA_STYLE chargeanim_style=$CA_STYLE boot_sound=$BS market=$(getprop ro.tran.sw.market 2>/dev/null)"
if [ "$BS" = "off" ]; then
    set_play_sound 0
else
    set_play_sound 1
fi

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

SRC_OGG=""
SRC_MP3=""
if [ "$BS" = "custom" ]; then
    BS_FILE=$(cfg_get boot_sound_file "")
    SRC_OGG=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.ogg" \
        "$MODDIR/product/media/audio/bootsound/custom.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/custom.ogg")
    SRC_MP3=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.mp3" \
        "$MODDIR/product/media/audio/bootsound/custom.mp3" \
        "$MODDIR/system/product/media/audio/bootsound/custom.mp3")
    SRC_WAV=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.wav" \
        "$MODDIR/product/media/audio/bootsound/custom.wav" \
        "$MODDIR/system/product/media/audio/bootsound/custom.wav")
    if [ -n "$BS_FILE" ]; then
        case "$BS_FILE" in
            *.ogg|*.OGG)
                [ -n "$SRC_OGG" ] || SRC_OGG=$(first_existing \
                    "$MODDIR/tr_product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/system/product/media/audio/bootsound/$BS_FILE")
                ;;
            *.mp3|*.MP3)
                [ -n "$SRC_MP3" ] || SRC_MP3=$(first_existing \
                    "$MODDIR/tr_product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/system/product/media/audio/bootsound/$BS_FILE")
                ;;
            *.wav|*.WAV)
                [ -n "$SRC_WAV" ] || SRC_WAV=$(first_existing \
                    "$MODDIR/tr_product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/system/product/media/audio/bootsound/$BS_FILE")
                ;;
        esac
    fi
    # MediaPlayer sniffs content. A wav can still sit on the mp3 candidate path.
    [ -z "$SRC_MP3" ] && [ -n "$SRC_WAV" ] && SRC_MP3="$SRC_WAV"
elif [ "$BS" != "off" ]; then
    SRC_OGG=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg")
    SRC_MP3=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz.mp3" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.mp3")
fi
log_pfd "bootsound ogg=${SRC_OGG:-none} mp3=${SRC_MP3:-none}"
log_bootanim_bin

# Transsion libbootanimation.so plays MediaPlayer files, not zip audio.wav.
# initAudioPath() walks three boot candidates (first that exists wins).
if [ "$BS" = "off" ]; then
    log_pfd "bootsound: off"
    rm -f /data/local/bootaudio.mp3
    rm -f "$MODDIR/tr_product/media/audio/bootsound/bootaudio.ogg"
    rm -f /mnt/vendor/mountify/tr_product/media/audio/bootsound/bootaudio.ogg
    [ -f "$STAGED" ] && strip_zip_audio "$STAGED"
else
    OGG_SRC="$SRC_OGG"
    [ -z "$OGG_SRC" ] && OGG_SRC="$SRC_MP3"
    MP3_SRC="$SRC_MP3"
    [ -z "$MP3_SRC" ] && MP3_SRC="$SRC_OGG"
    if [ -n "$OGG_SRC" ]; then
        place_boot_audio "$OGG_SRC" /product/media/audio/bootsound/Waltz.ogg
        place_boot_audio "$OGG_SRC" /tr_product/media/audio/bootsound/bootaudio.ogg
    else
        log_pfd "no ogg/mp3 source for Waltz.ogg / bootaudio.ogg"
    fi
    if [ -n "$MP3_SRC" ]; then
        place_boot_audio "$MP3_SRC" /data/local/bootaudio.mp3
    else
        log_pfd "no source for /data/local/bootaudio.mp3"
    fi
fi
log_pfd "live boot-audio candidates:"
ls -l /product/media/audio/bootsound/Waltz.ogg \
      /tr_product/media/audio/bootsound/bootaudio.ogg \
      /data/local/bootaudio.mp3 >> "$PFD_LOG" 2>/dev/null

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
log_pfd "live /tr_product/media (stock audio tree, zip bound):"
ls -la /tr_product/media >> "$PFD_LOG" 2>/dev/null
ls -la /tr_product/media/audio >> "$PFD_LOG" 2>/dev/null
ls -la /tr_product/media/audio/bootsound >> "$PFD_LOG" 2>/dev/null

# Charging animation. Stock dump XML is /product/theme/charge/; live OS 16
# uses /tr_product. Bind only the charge dir — never /tr_product or /theme.
log_pfd "live /tr_product/theme:"
ls -la /tr_product/theme >> "$PFD_LOG" 2>/dev/null
ls -la /tr_product/theme/charge >> "$PFD_LOG" 2>/dev/null
ls -la /product/theme/charge >> "$PFD_LOG" 2>/dev/null

CHARGE_PACK=""
for d in "$MODDIR/system/product/theme/charge" "$MODDIR/product/theme/charge"; do
    if [ -f "$d/lockscreen_charge_config.xml" ]; then
        CHARGE_PACK="$d"
        break
    fi
done
log_pfd "CHARGE_PACK=${CHARGE_PACK:-none} style=$CA_STYLE"

if [ "$CA_STYLE" = "off" ]; then
    log_pfd "chargeanim: off — leave stock charge theme"
    rm -rf "$MODDIR/tr_product/theme/charge"
    rm -rf /mnt/vendor/mountify/tr_product/theme/charge
elif [ -z "$CHARGE_PACK" ]; then
    log_pfd "chargeanim: no pack xml in module"
else
    SRC_MP4=""
    FNAME=""
    case "$CA_STYLE" in
        default)
            FNAME="xos_wire_charging_lockscreen.mp4"
            SRC_MP4=$(first_existing "$CHARGE_PACK/$FNAME")
            ;;
        custom)
            FNAME="custom.mp4"
            SRC_MP4=$(first_existing \
                "$MODDIR/system/product/theme/charge/custom.mp4" \
                "$MODDIR/charge_custom.mp4" \
                "$MODDIR/tr_product/theme/charge/custom.mp4" \
                "$MODDIR/product/theme/charge/custom.mp4")
            ;;
        *)
            FNAME="hios_wire_charging_lockscreen.mp4"
            SRC_MP4=$(first_existing "$CHARGE_PACK/$FNAME")
            ;;
    esac
    if [ -z "$SRC_MP4" ] || [ ! -f "$SRC_MP4" ]; then
        log_pfd "chargeanim: no mp4 for style=$CA_STYLE"
    else
        cp -f "$SRC_MP4" "$MODDIR/.charge_pick.mp4"
        SRC_MP4="$MODDIR/.charge_pick.mp4"
        CA_MD5=$(file_md5 "$SRC_MP4")
        log_pfd "chargeanim mp4=$FNAME md5=${CA_MD5:-none} from style=$CA_STYLE"
        if [ -n "$CA_MD5" ]; then
            CHARGE_TR="$MODDIR/.charge_tr"
            CHARGE_PROD="$MODDIR/.charge_prod"
            rm -rf "$CHARGE_TR" "$CHARGE_PROD"
            stage_charge_tree "$CHARGE_TR" \
                "/tr_product/theme/charge/" "$CHARGE_PACK" "$SRC_MP4" "$FNAME" "$CA_MD5"
            stage_charge_tree "$CHARGE_PROD" \
                "/product/theme/charge/" "$CHARGE_PACK" "$SRC_MP4" "$FNAME" "$CA_MD5"
            mkdir -p "$MODDIR/tr_product/theme/charge"
            cp -a "$CHARGE_TR"/. "$MODDIR/tr_product/theme/charge/"
            if [ -d /mnt/vendor/mountify/tr_product ]; then
                mkdir -p /mnt/vendor/mountify/tr_product/theme/charge
                cp -a "$CHARGE_TR"/. /mnt/vendor/mountify/tr_product/theme/charge/
                chmod 644 /mnt/vendor/mountify/tr_product/theme/charge/* 2>/dev/null
                log_pfd "mountify theme/charge"
            fi
            log_pfd "charge xml resourcePath:"
            grep resourcePath "$CHARGE_TR/lockscreen_charge_config.xml" >> "$PFD_LOG" 2>/dev/null
            grep fileName "$CHARGE_TR/lockscreen_charge_config.xml" | head -3 >> "$PFD_LOG" 2>/dev/null
            for dest in /tr_product/theme/charge /product/theme/charge /system/product/theme/charge; do
                case "$dest" in
                    /tr_product/*)
                        [ -d /tr_product ] || continue
                        src="$CHARGE_TR"
                        ;;
                    /product/*)
                        [ -d /product ] || continue
                        src="$CHARGE_PROD"
                        ;;
                    /system/product/*)
                        [ -d /system/product ] || continue
                        src="$CHARGE_PROD"
                        ;;
                    *) continue ;;
                esac
                if ! ensure_dir "$dest"; then
                    log_pfd "charge dest missing: $dest"
                    continue
                fi
                bind_over_dir "$src" "$dest"
            done
            for dest in $(find_named lockscreen_charge_config.xml) \
                        $(find_named xos_wire_charging_lockscreen.mp4) \
                        $(find_named hios_wire_charging_lockscreen.mp4); do
                dir=$(dirname "$dest")
                base=$(basename "$dest")
                case "$dir" in
                    /tr_product/*) src="$CHARGE_TR" ;;
                    *) src="$CHARGE_PROD" ;;
                esac
                case "$base" in
                    *.mp4) try_bind_file "$src/$FNAME" "$dest" ;;
                    *) try_bind_file "$src/$base" "$dest" ;;
                esac
            done
            log_pfd "chargeanim bind pass done"
            ls -la /tr_product/theme/charge >> "$PFD_LOG" 2>/dev/null
            if command -v resetprop >/dev/null 2>&1; then
                resetprop -n ro.tran.charge_animation_support 1 2>/dev/null \
                    || resetprop ro.tran.charge_animation_support 1 2>/dev/null
                resetprop -n ro.tran.lockscreen_charge_anim 1 2>/dev/null \
                    || resetprop ro.tran.lockscreen_charge_anim 1 2>/dev/null
            fi
        else
            log_pfd "chargeanim: could not md5 $SRC_MP4"
        fi
    fi
fi

