#!/system/bin/sh
# Custom UI sounds. GT dump lives at /tr_product/media/audio/ui/*.ogg
# Mountify does not overlay tr_product — per-file bind like bootanim.
# Also stage dest-named .ogg under module system/product so Mountify can
# overlay /product (Flagship 15 path). Stock = no bind, remove staged dest.
# Do not bind-dir /tr_product. Do not pack Waltz / bootsound / theme/charge.

if [ -z "$MODDIR" ]; then
  MODDIR=${0%/*}
fi
[ -n "$CFG" ] || CFG="$MODDIR/config.json"

os16_snd_log() {
  if [ -n "$PFD_LOG" ]; then
    echo "[$(date '+%H:%M:%S')] sounds: $1" >> "$PFD_LOG"
  elif [ -n "$LOG" ]; then
    echo "[$(date '+%H:%M:%S')] sounds: $1" >> "$LOG"
  fi
}

os16_snd_cfg() {
  k="$1"; d="$2"
  [ -f "$CFG" ] || { echo "$d"; return; }
  val=$(grep -o "\"$k\"[[:space:]]*:[[:space:]]*[^,}]*" "$CFG" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '" ')
  [ -n "$val" ] && echo "$val" || echo "$d"
}

os16_snd_nsenter() {
  if [ -x /system/bin/nsenter ]; then
    echo "/system/bin/nsenter -t 1 -m --"
  elif command -v nsenter >/dev/null 2>&1; then
    echo "nsenter -t 1 -m --"
  fi
}

os16_snd_umount() {
  dest="$1"
  ns=$(os16_snd_nsenter)
  [ -n "$ns" ] && $ns umount -l "$dest" >/dev/null 2>&1
  umount -l "$dest" >/dev/null 2>&1
}

os16_snd_bind() {
  src="$1"
  dest="$2"
  [ -f "$src" ] || return 1
  ns=$(os16_snd_nsenter)
  if [ ! -e "$dest" ]; then
    parent=$(dirname "$dest")
    if [ -d "$parent" ]; then
      touch "$dest" 2>/dev/null
      [ -n "$ns" ] && $ns touch "$dest" 2>/dev/null
    fi
  fi
  [ -e "$dest" ] || { os16_snd_log "bind skip (no dest) $dest"; return 1; }
  chcon --reference="$dest" "$src" 2>/dev/null
  chmod 644 "$src" 2>/dev/null
  os16_snd_umount "$dest"
  if [ -n "$ns" ] && $ns mount --bind "$src" "$dest"; then
    os16_snd_log "bind OK $dest"
    return 0
  fi
  if mount --bind "$src" "$dest"; then
    os16_snd_log "bind local OK $dest"
    return 0
  fi
  os16_snd_log "bind FAIL $src -> $dest"
  return 1
}

os16_snd_custom_src() {
  destbase="$1"
  for dir in \
      "$MODDIR/system/product/media/audio/ui" \
      "$MODDIR/system/media/audio/ui" \
      "$MODDIR/product/media/audio/ui" \
      "$MODDIR/tr_product/media/audio/ui"; do
    for f in "$dir/${destbase}_custom".*; do
      [ -f "$f" ] && { echo "$f"; return 0; }
    done
  done
  return 1
}

os16_snd_stage_dirs() {
  echo "$MODDIR/system/product/media/audio/ui"
  echo "$MODDIR/system/media/audio/ui"
  echo "$MODDIR/product/media/audio/ui"
}

os16_snd_mountify_dirs() {
  echo "/mnt/vendor/mountify/product/media/audio/ui"
  echo "/mnt/vendor/mountify/system/product/media/audio/ui"
  echo "/mnt/vendor/mountify/tr_product/media/audio/ui"
}

os16_snd_live_dirs() {
  echo "/tr_product/media/audio/ui"
  echo "/product/media/audio/ui"
  echo "/system/product/media/audio/ui"
  echo "/system/media/audio/ui"
}

os16_snd_alias_names() {
  destbase="$1"
  echo "${destbase}.ogg"
  if [ "$destbase" = "ChargingStarted" ]; then
    echo "charging_sound.ogg"
    echo "ChargingStarted.mp3"
  fi
  if [ "$destbase" = "WirelessChargingStarted" ]; then
    echo "WirelessChargingStarted.mp3"
  fi
  if [ "$destbase" = "Unlock" ]; then
    echo "Unlock.mp3"
  fi
}

os16_snd_stage() {
  src="$1"
  destbase="$2"
  [ -f "$src" ] || return 1
  os16_snd_stage_dirs | while read -r dir; do
    [ -n "$dir" ] || continue
    mkdir -p "$dir"
    os16_snd_alias_names "$destbase" | while read -r name; do
      [ -n "$name" ] || continue
      cp -f "$src" "$dir/$name"
      chmod 644 "$dir/$name" 2>/dev/null
    done
  done
  os16_snd_mountify_dirs | while read -r dir; do
    [ -d /mnt/vendor/mountify ] || continue
    mkdir -p "$dir" 2>/dev/null
    [ -d "$dir" ] || continue
    os16_snd_alias_names "$destbase" | while read -r name; do
      [ -n "$name" ] || continue
      cp -f "$src" "$dir/$name" 2>/dev/null
      chmod 644 "$dir/$name" 2>/dev/null
    done
  done
}

os16_snd_unstage() {
  destbase="$1"
  os16_snd_stage_dirs | while read -r dir; do
    os16_snd_alias_names "$destbase" | while read -r name; do
      [ -n "$name" ] || continue
      rm -f "$dir/$name"
    done
  done
  os16_snd_mountify_dirs | while read -r dir; do
    os16_snd_alias_names "$destbase" | while read -r name; do
      [ -n "$name" ] || continue
      rm -f "$dir/$name"
    done
  done
}

os16_snd_bind_names() {
  src="$1"
  destbase="$2"
  os16_snd_alias_names "$destbase" | while read -r name; do
    [ -n "$name" ] || continue
    os16_snd_live_dirs | while read -r dir; do
      [ -d "$dir" ] || continue
      os16_snd_bind "$src" "$dir/$name"
    done
  done
}

os16_snd_umount_names() {
  destbase="$1"
  os16_snd_alias_names "$destbase" | while read -r name; do
    [ -n "$name" ] || continue
    os16_snd_live_dirs | while read -r dir; do
      [ -n "$dir" ] || continue
      os16_snd_umount "$dir/$name"
    done
  done
}

# id destbase  (dest file is destbase.ogg on device)
os16_snd_slots() {
  cat <<'EOF'
chargesound ChargingStarted
wirelesschargesound WirelessChargingStarted
sound_Unlock Unlock
sound_Lock Lock
sound_Screenshots Screenshots
sound_Effect_Tick Effect_Tick
sound_Fail Fail
sound_Success Success
sound_Sent_Success Sent_Success
sound_LowBattery LowBattery
sound_KeypressStandard KeypressStandard
sound_KeypressDelete KeypressDelete
sound_KeypressReturn KeypressReturn
sound_KeypressSpacebar KeypressSpacebar
sound_delete delete
sound_Disconnect Disconnect
sound_InCallNotification InCallNotification
sound_Gear Gear
sound_Calculagraph Calculagraph
sound_beep_once beep_once
sound_beep_twice beep_twice
sound_Second_Hand Second_Hand
sound_Cobalt Cobalt
sound_Dock Dock
sound_KeypressInvalid KeypressInvalid
sound_Trusted Trusted
sound_Undock Undock
sound_sent_message_success sent_message_success
EOF
}

os16_umount_sounds() {
  os16_snd_slots | while read -r id destbase; do
    [ -n "$id" ] || continue
    os16_snd_umount_names "$destbase"
    os16_snd_unstage "$destbase"
  done
}

os16_apply_sounds() {
  os16_snd_slots | while read -r id destbase; do
    [ -n "$id" ] || continue
    style=$(os16_snd_cfg "${id}_style" stock)
    if [ "$style" != "custom" ]; then
      os16_snd_umount_names "$destbase"
      os16_snd_unstage "$destbase"
      os16_snd_log "$id stock (no bind)"
      continue
    fi
    src=$(os16_snd_custom_src "$destbase")
    if [ -z "$src" ]; then
      os16_snd_log "$id custom but no ${destbase}_custom.* uploaded"
      continue
    fi
    os16_snd_stage "$src" "$destbase"
    os16_snd_bind_names "$src" "$destbase"
    os16_snd_log "$id custom src=$src size=$(wc -c < "$src" 2>/dev/null)"
  done
}

if [ "${0##*/}" = "apply_sounds.sh" ]; then
  os16_apply_sounds
fi
