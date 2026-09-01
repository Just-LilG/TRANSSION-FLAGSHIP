#!/system/bin/sh
# Re-bind staged boot/reboot zips after Mountify META remounts overlays.
# Do not umount all of /tr_product/media.

os16_bootanim_nsenter() {
  if [ -x /system/bin/nsenter ]; then
    echo "/system/bin/nsenter -t 1 -m --"
  elif command -v nsenter >/dev/null 2>&1; then
    echo "nsenter -t 1 -m --"
  fi
}

os16_bind_one_bootzip() {
  _src="$1"
  _dst="$2"
  _ns="$3"
  [ -f "$_src" ] || return 0
  mkdir -p "$(dirname "$_dst")" 2>/dev/null
  if [ ! -e "$_dst" ]; then
    touch "$_dst" 2>/dev/null
    [ -n "$_ns" ] && $_ns touch "$_dst" 2>/dev/null
  fi
  [ -e "$_dst" ] || return 0
  chcon --reference="$_dst" "$_src" 2>/dev/null
  chmod 0644 "$_src" 2>/dev/null
  if [ -n "$_ns" ]; then
    $_ns umount -l "$_dst" 2>/dev/null
    if $_ns mount --bind "$_src" "$_dst"; then
      chmod 0644 "$_dst" 2>/dev/null
      return 0
    fi
  fi
  umount -l "$_dst" 2>/dev/null
  mount --bind "$_src" "$_dst" 2>/dev/null
  chmod 0644 "$_dst" 2>/dev/null
}

os16_stage_bootzip_into_mountify() {
  _src="$1"
  _name="$2"
  [ -f "$_src" ] || return 0
  _mnt="/mnt/vendor/mountify/tr_product/media"
  if [ -d /mnt/vendor/mountify ]; then
    mkdir -p "$_mnt" 2>/dev/null
    cp -f "$_src" "$_mnt/$_name" 2>/dev/null
    chmod 0644 "$_mnt/$_name" 2>/dev/null
  fi
}

os16_bind_staged_bootanim() {
  _mod="${MODDIR:-/data/adb/modules/transsion-flagship-16}"
  _boot="${_mod}/tr_product/media/bootanimation.zip"
  _re="${_mod}/tr_product/media/rebootanimation.zip"
  _ns=$(os16_bootanim_nsenter)
  os16_stage_bootzip_into_mountify "$_boot" "bootanimation.zip"
  os16_stage_bootzip_into_mountify "$_re" "rebootanimation.zip"
  os16_bind_one_bootzip "$_boot" /tr_product/media/bootanimation.zip "$_ns"
  os16_bind_one_bootzip "$_boot" /tr_product/media/bootanimation-dark.zip "$_ns"
  os16_bind_one_bootzip "$_re" /tr_product/media/rebootanimation.zip "$_ns"
  os16_bind_one_bootzip "$_re" /tr_product/media/shutdownanimation.zip "$_ns"
  os16_bind_one_bootzip "$_boot" /product/media/bootanimation.zip "$_ns"
  os16_bind_one_bootzip "$_re" /product/media/rebootanimation.zip "$_ns"
  os16_bind_one_bootzip "$_boot" /system/product/media/bootanimation.zip "$_ns"
  os16_bind_one_bootzip "$_boot" /system/media/bootanimation.zip "$_ns"
}

if [ "${0##*/}" = "apply_bootanim.sh" ]; then
  os16_bind_staged_bootanim
fi
