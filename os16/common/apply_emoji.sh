#!/system/bin/sh
# Custom emoji font. Bind packed or uploaded TTF over the stock color-emoji file.
# Do not replace NotoColorEmojiFlags.ttf.

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"

os16_emoji_log() {
  if [ -n "$PFD_LOG" ]; then
    echo "[$(date '+%H:%M:%S')] emoji: $1" >> "$PFD_LOG"
  elif [ -n "$LOG" ]; then
    echo "[$(date '+%H:%M:%S')] emoji: $1" >> "$LOG"
  fi
}

os16_emoji_cfg() {
  k="$1"; d="$2"
  [ -f "$CFG" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

os16_emoji_on() {
  v=$(os16_emoji_cfg emoji_font true)
  [ "$v" != "false" ]
}

os16_emoji_nsenter() {
  if [ -x /system/bin/nsenter ]; then
    echo "/system/bin/nsenter -t 1 -m --"
  elif command -v nsenter >/dev/null 2>&1; then
    echo "nsenter -t 1 -m --"
  fi
}

os16_emoji_umount() {
  dest="$1"
  ns=$(os16_emoji_nsenter)
  [ -n "$ns" ] && $ns umount -l "$dest" >/dev/null 2>&1
  umount -l "$dest" >/dev/null 2>&1
}

os16_emoji_bind() {
  src="$1"
  dest="$2"
  [ -f "$src" ] || return 1
  ns=$(os16_emoji_nsenter)
  parent=$(dirname "$dest")
  if [ ! -d "$parent" ]; then
    return 1
  fi
  if [ ! -e "$dest" ]; then
    touch "$dest" 2>/dev/null
    [ -e "$dest" ] || { [ -n "$ns" ] && $ns touch "$dest" 2>/dev/null; }
  fi
  [ -e "$dest" ] || { os16_emoji_log "bind skip (no dest) $dest"; return 1; }
  chcon --reference="$dest" "$src" 2>/dev/null
  chmod 644 "$src" 2>/dev/null
  os16_emoji_umount "$dest"
  if [ -n "$ns" ] && $ns mount --bind "$src" "$dest"; then
    os16_emoji_log "bind OK $dest"
    return 0
  fi
  if mount --bind "$src" "$dest"; then
    os16_emoji_log "bind local OK $dest"
    return 0
  fi
  os16_emoji_log "bind FAIL $src -> $dest"
  return 1
}

os16_emoji_dests() {
  echo "/system/fonts/NotoColorEmoji.ttf"
  echo "/system/system/fonts/NotoColorEmoji.ttf"
  echo "/product/fonts/NotoColorEmoji.ttf"
  echo "/system/product/fonts/NotoColorEmoji.ttf"
}

os16_emoji_packed() {
  echo "$MODDIR/system/fonts/NotoColorEmoji.ttf"
}

os16_emoji_custom() {
  echo "$MODDIR/system/fonts/NotoColorEmoji_custom.ttf"
}

os16_emoji_enable_packed() {
  p=$(os16_emoji_packed)
  [ -f "${p}.disabled" ] && mv "${p}.disabled" "$p"
}

os16_emoji_disable_packed() {
  p=$(os16_emoji_packed)
  [ -f "$p" ] && mv "$p" "${p}.disabled"
}

os16_umount_emoji() {
  os16_emoji_dests | while read -r dest; do
    [ -n "$dest" ] || continue
    os16_emoji_umount "$dest"
  done
}

os16_apply_emoji() {
  custom=$(os16_emoji_custom)
  packed=$(os16_emoji_packed)
  if ! os16_emoji_on; then
    os16_umount_emoji
    os16_emoji_disable_packed
    os16_emoji_log "off (stock ROM font)"
    return 0
  fi
  os16_emoji_enable_packed
  src=""
  if [ -f "$custom" ]; then
    src="$custom"
  elif [ -f "$packed" ]; then
    src="$packed"
  elif [ -f "${packed}.disabled" ]; then
    mv "${packed}.disabled" "$packed"
    src="$packed"
  fi
  if [ -z "$src" ] || [ ! -f "$src" ]; then
    os16_emoji_log "on but no TTF in $MODDIR/system/fonts"
    return 1
  fi
  chmod 644 "$src" 2>/dev/null
  os16_emoji_dests | while read -r dest; do
    [ -e "$dest" ] || continue
    case "$dest" in
      *Flags*) continue ;;
    esac
    os16_emoji_bind "$src" "$dest"
  done
  os16_emoji_log "on src=$src size=$(wc -c < "$src" 2>/dev/null)"
}

if [ "${0##*/}" = "apply_emoji.sh" ]; then
  os16_apply_emoji
fi
