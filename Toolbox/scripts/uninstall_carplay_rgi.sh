#!/bin/sh
export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/media/gracenote/bin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH

if [ "$_" = "/bin/on" ]; then BASE="$0"; else BASE="$_"; fi
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$BASE")")" && pwd -P )

# Include info script
. ${SCRIPTDIR}/util_info.sh

# Include SD card mount script
. ${SCRIPTDIR}/util_mountsd.sh
if [[ -z "$VOLUME" ]]
then
  echo "No SD-card found, quitting"
  exit 0
fi

HOOK_TARGET="/mnt/app/root/hooks"
JAR_TARGET="/mnt/app/eso/hmi/lsd/jars"
CONFIG_TARGET="/mnt/system/etc/eso/production"
SMARTPHONE_JSON="${CONFIG_TARGET}/smartphone_integrator.json"
DIO_JSON="${CONFIG_TARGET}/dio_manager.json"
BACKUPFOLDER="${VOLUME}/Backup/${VERSION}/${FAZIT}/CarPlayRGI"

restore_file() {
  FILENAME="$1"
  DEST="$2"
  SRC="${BACKUPFOLDER}/${FILENAME}"

  if [ -f "${SRC}" ]; then
    echo "Restoring ${DEST} from backup"
    cp -v "${SRC}" "${DEST}"
  else
    echo "ERROR: Missing backup ${SRC}"
    echo "Restore aborted. Installed files were not removed."
    mount -ur /mnt/app 2>/dev/null
    mount -ur /mnt/system 2>/dev/null
    exit 0
  fi
}

mount -uw /mnt/app
mount -uw /mnt/system

restore_file "smartphone_integrator.json" "${SMARTPHONE_JSON}"
restore_file "dio_manager.json" "${DIO_JSON}"

echo "Removing CarPlay RGI files"
rm -fv "${HOOK_TARGET}/libcarplay_hook.so"
rm -fv "${HOOK_TARGET}/maneuver_render"
rm -fv "${HOOK_TARGET}/flag_atlas.rgba"
rm -fv "${JAR_TARGET}/carplay_hook.jar"

sync
sleep 1
mount -ur /mnt/app
mount -ur /mnt/system

echo "CarPlay Route Guidance Interface restored."
echo "Please wait at least 30 seconds, then reboot the headunit."

exit 0
