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
# KernelSU may not happen at all without a metamodule). Android 16 also prefers
# /product/media/bootanimation.zip over /system/media/, so the module tree
# never wins on XOS 16. Bind-mount the prepared files over every live path.
bind_over_file() {
    src="$1"
    dest="$2"
    [ -f "$src" ] || return 1
    [ -e "$dest" ] || { log_pfd "bind skip (no dest): $dest"; return 1; }
    chcon --reference="$dest" "$src" 2>/dev/null
    chmod 644 "$src" 2>/dev/null
    umount -l "$dest" 2>/dev/null
    if mount --bind "$src" "$dest"; then
        log_pfd "bind OK $dest"
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
    umount -l "$dest" 2>/dev/null
    if mount --bind "$src" "$dest"; then
        log_pfd "bind-dir OK $dest"
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
    /product/media/bootanimation.zip \
    /system/product/media/bootanimation.zip \
    /system/media/bootanimation.zip \
    /oem/media/bootanimation.zip \
    /apex/com.android.bootanimation/etc/bootanimation.zip \
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
    umount -l "$dest" 2>/dev/null
done

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

ANIM_DIR="$MODDIR/system/product/theme/animations"
MEDIA_DIRS="$MODDIR/system/media $MODDIR/system/product/media"
[ -d "$MODDIR/product" ] && MEDIA_DIRS="$MEDIA_DIRS $MODDIR/product/media"

BA_STYLE=$(cfg_get bootanim_style "default")
for dir in $MEDIA_DIRS; do
    mkdir -p "$dir"
    DEST="$dir/bootanimation.zip"
    case "$BA_STYLE" in
        off)
            rm -f "$DEST"
            ;;
        custom)
            for f in "$dir"/bootanimation_custom.*; do
                [ -e "$f" ] || continue
                rm -f "$DEST"
                cp "$f" "$DEST"
                break
            done
            ;;
        default|hios16)
            [ -f "$ANIM_DIR/bootanim_$BA_STYLE.zip" ] && cp "$ANIM_DIR/bootanim_$BA_STYLE.zip" "$DEST"
            ;;
    esac
done

SA_STYLE=$(cfg_get shutdownanim_style "default")
for dir in $MEDIA_DIRS; do
    mkdir -p "$dir"
    DEST="$dir/shutdownanimation.zip"
    case "$SA_STYLE" in
        off)
            rm -f "$DEST"
            ;;
        custom)
            for f in "$dir"/shutdownanimation_custom.*; do
                [ -e "$f" ] || continue
                rm -f "$DEST"
                cp "$f" "$DEST"
                break
            done
            ;;
        default|hios16)
            [ -f "$ANIM_DIR/shutdownanim_$SA_STYLE.zip" ] && cp "$ANIM_DIR/shutdownanim_$SA_STYLE.zip" "$DEST"
            ;;
    esac
done

# Apply before OverlayFS: XOS 16 / Android 16 reads /product/media first, and
# bootanim starts before KernelSU OverlayFS (and often before Magisk Magic Mount).
if [ "$BA_STYLE" != "off" ]; then
    SRC_BOOTANIM=$(first_existing \
        "$MODDIR/product/media/bootanimation.zip" \
        "$MODDIR/system/product/media/bootanimation.zip" \
        "$MODDIR/system/media/bootanimation.zip")
    if [ -n "$SRC_BOOTANIM" ]; then
        log_pfd "bootanim src=$SRC_BOOTANIM style=$BA_STYLE"
        for dest in \
            /product/media/bootanimation.zip \
            /system/product/media/bootanimation.zip \
            /system/media/bootanimation.zip \
            /oem/media/bootanimation.zip \
            /apex/com.android.bootanimation/etc/bootanimation.zip
        do
            bind_over_file "$SRC_BOOTANIM" "$dest"
        done
    else
        log_pfd "bootanim: no module zip to bind (style=$BA_STYLE)"
    fi
else
    log_pfd "bootanim: off — left stock paths unbound"
fi

if [ "$SA_STYLE" != "off" ]; then
    SRC_SHUTDOWN=$(first_existing \
        "$MODDIR/product/media/shutdownanimation.zip" \
        "$MODDIR/system/product/media/shutdownanimation.zip" \
        "$MODDIR/system/media/shutdownanimation.zip")
    if [ -n "$SRC_SHUTDOWN" ]; then
        log_pfd "shutdownanim src=$SRC_SHUTDOWN style=$SA_STYLE"
        for dest in \
            /product/media/shutdownanimation.zip \
            /system/product/media/shutdownanimation.zip \
            /system/media/shutdownanimation.zip \
            /oem/media/shutdownanimation.zip
        do
            bind_over_file "$SRC_SHUTDOWN" "$dest"
        done
    fi
fi

if [ "$BS_ON" = "1" ]; then
    SRC_BOOTSOUND=$(first_existing \
        "$MODDIR/product/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/media/audio/bootsound/Waltz.ogg" \
        "$MODDIR/system/media/audio/ui/Waltz.ogg")
    if [ -n "$SRC_BOOTSOUND" ]; then
        log_pfd "bootsound src=$SRC_BOOTSOUND"
        SRC_BOOTSOUND_DIR=""
        for d in \
            "$MODDIR/product/media/audio/bootsound" \
            "$MODDIR/system/product/media/audio/bootsound" \
            "$MODDIR/system/media/audio/bootsound"
        do
            [ -d "$d" ] && [ -f "$d/Waltz.ogg" ] && SRC_BOOTSOUND_DIR="$d" && break
        done
        # AOSP / some XOS 16 builds play PowerOn.ogg from ui/, not the bootsound folder
        for dest in \
            /product/media/audio/ui/PowerOn.ogg \
            /system/product/media/audio/ui/PowerOn.ogg \
            /system/media/audio/ui/PowerOn.ogg \
            /system/media/bootsound.ogg \
            /system/media/bootsound.mp3 \
            /system/media/audio/bootaudio.mp3
        do
            bind_over_file "$SRC_BOOTSOUND" "$dest"
        done
        # Transsion XOS 15 played whatever is in media/audio/bootsound/. Bind the
        # whole folder so Waltz.ogg is visible even when OverlayFS hasn't mounted.
        for dir in \
            /product/media/audio/bootsound \
            /system/product/media/audio/bootsound \
            /system/media/audio/bootsound
        do
            if [ -n "$SRC_BOOTSOUND_DIR" ] && bind_over_dir "$SRC_BOOTSOUND_DIR" "$dir"; then
                :
            elif [ -d "$dir" ]; then
                for f in "$dir"/*; do
                    [ -f "$f" ] || continue
                    bind_over_file "$SRC_BOOTSOUND" "$f"
                done
            fi
        done
    else
        log_pfd "bootsound: Waltz.ogg missing — nothing to bind"
    fi
else
    log_pfd "bootsound: off — left stock paths unbound"
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
