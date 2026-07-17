#!/system/bin/sh

MODDIR=${0%/*}
CFG="$MODDIR/config.json"

cfg_get() {
    [ -f "$CFG" ] || { echo "$2"; return; }
    val=$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" \
          | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
    [ -n "$val" ] && echo "$val" || echo "$2"
}
cfg_bool() { [ "$(cfg_get "$1" "$2")" = "true" ] && echo 1 || echo 0; }


BS_ON=$(cfg_bool boot_sound true)
for f in "$MODDIR/system/product/media/audio/bootsound/Waltz.ogg"; do
    if [ "$BS_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

BA_ON=$(cfg_bool boot_anim true)
for f in "$MODDIR/system/media/bootanimation.zip" "$MODDIR/system/product/media/bootanimation.zip"; do
    if [ "$BA_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

SA_ON=$(cfg_bool shutdown_anim true)
for f in "$MODDIR/system/media/shutdownanimation.zip" "$MODDIR/system/product/media/shutdownanimation.zip"; do
    if [ "$SA_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

EF_ON=$(cfg_bool emoji_font true)
for f in "$MODDIR/system/fonts/NotoColorEmoji.ttf" "$MODDIR/system/product/fonts/NotoColorEmoji.ttf"; do
    if [ "$EF_ON" = "0" ]; then
        [ -f "$f" ] && mv "$f" "${f}.disabled"
    else
        [ -f "${f}.disabled" ] && mv "${f}.disabled" "$f"
    fi
done

for part in /cache /system /vendor /data /product /metadata /odm /data/dalvik-cache; do
  [ -d "$part" ] && fstrim -v "$part" > /dev/null 2>&1
done
[ -d /preload ] && fstrim -v /preload > /dev/null 2>&1
