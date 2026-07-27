#!/bin/sh
export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/media/gracenote/bin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH

if [ "$_" = "/bin/on" ]; then BASE="$0"; else BASE="$_"; fi
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$BASE")")" && pwd -P )

# Include SD card mount script
. ${SCRIPTDIR}/util_mountsd.sh

if [ -n "$VOLUME" ]; then
  OUT="${VOLUME}/carplay_rgi_MHI2Q_CN_AUG22_P1002_logs.txt"
else
  OUT="/net/mmx/fs/sda0/carplay_rgi_MHI2Q_CN_AUG22_P1002_logs.txt"
fi

show_file() {
  FILE="$1"
  if [ -f "$FILE" ]; then
    cat "$FILE"
  else
    echo "Missing: $FILE"
  fi
}

{
echo "===== MHI2Q CarPlay RGI check ====="
echo "Firmware: MHI2Q_CN_AUG22_P1002"
date

echo
echo "===== Check installed files ====="
ls -l /mnt/app/root/hooks/libcarplay_hook.so 2>&1
ls -l /mnt/app/root/hooks/maneuver_render 2>&1
ls -l /mnt/app/root/hooks/flag_atlas.rgba 2>&1
ls -l /mnt/app/eso/hmi/lsd/jars/carplay_hook.jar 2>&1

echo
echo "===== Check smartphone_integrator.json LD_PRELOAD ====="
grep -n "LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so" /mnt/system/etc/eso/production/smartphone_integrator.json 2>&1

echo
echo "===== Check dio_manager.json RGI message IDs ====="
grep -n "0x5200\|0x5201\|0x5202\|0x5203\|0x5204" /mnt/system/etc/eso/production/dio_manager.json 2>&1

echo
echo "===== Show related dio_manager.json sections ====="
grep -n -A 8 -B 2 "MessagesSentByAccessory\|MessagesReceivedFromDevice" /mnt/system/etc/eso/production/dio_manager.json 2>&1

echo
echo "===== Check possible navignore / dual navigation traces ====="
grep -Rni "nav_active\|navigation-active\|navignore\|dual" /mnt/system/etc/eso /mnt/app/eso 2>/dev/null

echo
echo "===== carplay_hook.log ====="
show_file /tmp/carplay_hook.log

echo
echo "===== maneuver_render.log ====="
show_file /tmp/maneuver_render.log

echo
echo "===== Done ====="
} > "$OUT"

echo "CarPlay RGI diagnostic log saved to:"
echo "$OUT"

exit 0
