#!/bin/sh
export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/media/gracenote/bin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH

if [ "$_" = "/bin/on" ]; then BASE="$0"; else BASE="$_"; fi
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$BASE")")" && pwd -P )

# Include SD card mount script
. ${SCRIPTDIR}/util_mountsd.sh

if [ -n "$VOLUME" ]; then
  OUTDIR="${VOLUME}/CarPlayRGI_Diagnostics"
else
  OUTDIR="/net/mmx/fs/sda0/CarPlayRGI_Diagnostics"
fi

OUT="${OUTDIR}/carplay_rgi_MHI2Q_logs.txt"
SMARTPHONE_JSON="/mnt/system/etc/eso/production/smartphone_integrator.json"
DIO_JSON="/mnt/system/etc/eso/production/dio_manager.json"

mkdir -p "$OUTDIR"

show_file() {
  FILE="$1"
  if [ -f "$FILE" ]; then
    cat "$FILE"
  else
    echo "Missing: $FILE"
  fi
}

copy_file() {
  SRC="$1"
  DST="$2"
  if [ -f "$SRC" ]; then
    cp -v "$SRC" "$DST" 2>&1
  else
    echo "Missing: $SRC"
  fi
}

{
echo "===== MHI2Q CarPlay RGI check ====="

date

echo
echo "===== Check installed files ====="
ls -l /mnt/app/root/hooks/libcarplay_hook.so 2>&1
ls -l /mnt/app/root/hooks/maneuver_render 2>&1
ls -l /mnt/app/root/hooks/flag_atlas.rgba 2>&1
ls -l /mnt/app/eso/hmi/lsd/jars/carplay_hook.jar 2>&1

echo
echo "===== Check smartphone_integrator.json LD_PRELOAD ====="
grep -n "LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so" "$SMARTPHONE_JSON" 2>&1

echo
echo "===== Check dio_manager.json RGI message IDs ====="
grep -n "0x5200" "$DIO_JSON" 2>&1
grep -n "0x5201" "$DIO_JSON" 2>&1
grep -n "0x5202" "$DIO_JSON" 2>&1
grep -n "0x5203" "$DIO_JSON" 2>&1
grep -n "0x5204" "$DIO_JSON" 2>&1

echo
echo "===== dio_manager.json line count ====="
wc -l "$DIO_JSON" 2>&1

echo
echo "===== dio_manager.json first 220 lines ====="
sed -n '1,220p' "$DIO_JSON" 2>&1

echo
echo "===== Check possible navignore / dual navigation traces ====="
grep -Rni "nav_active" /mnt/system/etc/eso /mnt/app/eso 2>/dev/null
grep -Rni "navigation-active" /mnt/system/etc/eso /mnt/app/eso 2>/dev/null
grep -Rni "navignore" /mnt/system/etc/eso /mnt/app/eso 2>/dev/null
grep -Rni "dual" /mnt/system/etc/eso /mnt/app/eso 2>/dev/null

echo
echo "===== Check NavActiveIgnore jar and lsd.sh references ====="
ls -l /mnt/app/eso/hmi/lsd/jars/NavActiveIgnore.jar 2>&1
grep -n "NavActiveIgnore" /mnt/app/eso/hmi/lsd/lsd.sh 2>&1

echo
echo "===== carplay_hook.log ====="
show_file /tmp/carplay_hook.log

echo
echo "===== maneuver_render.log ====="
show_file /tmp/maneuver_render.log

echo
echo "===== Copy installed production JSON files ====="
copy_file "$SMARTPHONE_JSON" "${OUTDIR}/smartphone_integrator_new.json"
copy_file "$DIO_JSON" "${OUTDIR}/dio_manager_new.json"

echo
echo "===== Done ====="
} > "$OUT"

echo "CarPlay RGI diagnostic files saved to:"
echo "$OUTDIR"
echo "Main log:"
echo "$OUT"

exit 0
