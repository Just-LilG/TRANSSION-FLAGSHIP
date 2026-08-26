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
                "$ff" -y -i "$ogg" -acodec pcm_s16le -ac 1 -ar 22050 "$wav" >/dev/null 2>&1 && echo yes)
        else
            ok=$("$ff" -y -i "$ogg" -acodec pcm_s16le -ac 1 -ar 22050 "$wav" >/dev/null 2>&1 && echo yes)
        fi
        if [ "$ok" = "yes" ]; then
            log_pfd "converted ogg->wav with $ff"
            return 0
        fi
        log_pfd "ffmpeg failed: $ff"
    done
    return 1
}

run_player() {
    player="$1"
    wav="$2"
    shift 2
    if command -v timeout >/dev/null 2>&1; then
        if [ -n "$NSENTER" ]; then
            $NSENTER timeout 8 "$player" "$wav" "$@" && return 0
        fi
        timeout 8 "$player" "$wav" "$@"
        return $?
    fi
    if [ -n "$NSENTER" ]; then
        $NSENTER "$player" "$wav" "$@" && return 0
    fi
    "$player" "$wav" "$@"
}

play_boot_wav() {
    wav="$1"
    [ -f "$wav" ] || { log_pfd "tinyplay skip (no wav)"; return 1; }
    player=""
    for p in /system/bin/tinyplay /vendor/bin/tinyplay /system_ext/bin/tinyplay \
             /vendor/bin/hw/tinyplay /odm/bin/tinyplay \
             /system/bin/aplay /vendor/bin/aplay; do
        [ -x "$p" ] && { player="$p"; break; }
    done
    if [ -z "$player" ]; then
        player=$(find /system /vendor /system_ext /odm -name tinyplay -type f 2>/dev/null | head -n 1)
    fi
    if [ -z "$player" ]; then
        log_pfd "no tinyplay/aplay on device"
        ls -l /system/bin/tinyplay /vendor/bin/tinyplay /dev/snd 2>>"$PFD_LOG"
        find /system /vendor /system_ext /odm -name 'tinyplay' 2>/dev/null >>"$PFD_LOG"
        return 1
    fi
    log_pfd "boot play: $player $wav"
    # Do not block post-fs-data. PCM/HAL often appears after bootanim starts.
    (
        n=0
        while [ "$n" -lt 15 ]; do
            log_pfd "tinyplay attempt n=$n snd=$(ls /dev/snd 2>/dev/null | tr '\n' ' ')"
            if ls /dev/snd/pcmC*p >/dev/null 2>&1 || [ "$n" -ge 2 ]; then
                if run_player "$player" "$wav"; then
                    log_pfd "tinyplay OK (default) n=$n"
                    exit 0
                fi
                if run_player "$player" "$wav" -D 0 -d 0; then
                    log_pfd "tinyplay OK -D 0 -d 0 n=$n"
                    exit 0
                fi
                for pcm in /dev/snd/pcmC*p; do
                    [ -e "$pcm" ] || continue
                    base=$(basename "$pcm")
                    card=$(echo "$base" | sed -n 's/^pcmC\([0-9]*\)D\([0-9]*\)p$/\1/p')
                    dev=$(echo "$base" | sed -n 's/^pcmC\([0-9]*\)D\([0-9]*\)p$/\2/p')
                    [ -n "$card" ] || continue
                    if run_player "$player" "$wav" -D "$card" -d "$dev"; then
                        log_pfd "tinyplay OK -D $card -d $dev n=$n"
                        exit 0
                    fi
                done
                log_pfd "tinyplay try fail n=$n"
            fi
            n=$((n + 1))
            sleep 1
        done
        log_pfd "tinyplay gave up"
        ls -l /dev/snd >>"$PFD_LOG" 2>/dev/null
    ) >>"$PFD_LOG" 2>&1 &
    log_pfd "boot play pid=$!"
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
if [ "$BS" = "off" ]; then
    set_play_sound 0
else
    set_play_sound 1
fi

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
    BS_FILE=$(cfg_get boot_sound_file "")
    SRC_BOOTSOUND=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.ogg" \
        "$MODDIR/product/media/audio/bootsound/custom.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/custom.ogg")
    SRC_BOOTWAV=$(first_existing \
        "$MODDIR/tr_product/media/audio/bootsound/custom.wav" \
        "$MODDIR/product/media/audio/bootsound/custom.wav" \
        "$MODDIR/system/product/media/audio/bootsound/custom.wav")
    if [ -z "$SRC_BOOTSOUND" ] && [ -n "$BS_FILE" ]; then
        SRC_BOOTSOUND=$(first_existing \
            "$MODDIR/tr_product/media/audio/bootsound/$BS_FILE" \
            "$MODDIR/product/media/audio/bootsound/$BS_FILE" \
            "$MODDIR/system/product/media/audio/bootsound/$BS_FILE")
    fi
    if [ -z "$SRC_BOOTWAV" ] && [ -n "$BS_FILE" ]; then
        case "$BS_FILE" in
            *.wav|*.WAV)
                SRC_BOOTWAV=$(first_existing \
                    "$MODDIR/tr_product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/product/media/audio/bootsound/$BS_FILE" \
                    "$MODDIR/system/product/media/audio/bootsound/$BS_FILE")
                ;;
        esac
    fi
    # Prefer converting a freshly uploaded ogg over a stale custom.wav.
    if [ -n "$SRC_BOOTSOUND" ]; then
        mkdir -p "$MODDIR/tr_product/media/audio/bootsound"
        if convert_ogg_to_wav "$SRC_BOOTSOUND" "$MODDIR/tr_product/media/audio/bootsound/custom.wav"; then
            SRC_BOOTWAV="$MODDIR/tr_product/media/audio/bootsound/custom.wav"
        elif [ -z "$SRC_BOOTWAV" ]; then
            log_pfd "custom is ogg and no ffmpeg — zip/tinyplay need wav. Pick Waltz or upload .wav"
        fi
    fi
elif [ "$BS" != "off" ]; then
    SRC_BOOTWAV=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz_bootanim.wav" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz_bootanim.wav" \
        "$MODDIR/product/media/audio/bootsound/Waltz.wav" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.wav")
    SRC_BOOTSOUND=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg")
fi
log_pfd "bootsound ogg=${SRC_BOOTSOUND:-none} wav=${SRC_BOOTWAV:-none}"
log_bootanim_bin

# Stock XOS 16 audio/ has no PowerOn.ogg and no bootsound/. Binding that
# whole tree (V1.02–V1.04) nested alarms/notifications and hid UI sounds.
# Do not bind-dir /tr_product/media/audio. Only the boot zip + tinyplay.

if [ "$BS" != "off" ] && [ -n "$SRC_BOOTWAV" ] && [ -f "$STAGED" ]; then
    try_inject_audio "$STAGED" "$SRC_BOOTWAV"
    log_pfd "staged zip audio members:"
    ( unzip -l "$STAGED" 2>/dev/null || true ) | grep -i audio >> "$PFD_LOG"
elif [ "$BS" = "off" ]; then
    log_pfd "bootsound: off"
    [ -f "$STAGED" ] && strip_zip_audio "$STAGED"
elif [ -f "$STAGED" ]; then
    log_pfd "bootsound: no wav to inject"
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

if [ "$BS" != "off" ] && [ -n "$SRC_BOOTWAV" ]; then
    echo "$SRC_BOOTWAV" > "$MODDIR/.boot_play.wav"
    play_boot_wav "$SRC_BOOTWAV"
else
    rm -f "$MODDIR/.boot_play.wav"
fi
log_pfd "live audio after (should be stock tree, not module bind-dir):"
ls -la /tr_product/media/audio >> "$PFD_LOG" 2>/dev/null
ls -la /tr_product/media/audio/ui >> "$PFD_LOG" 2>/dev/null

