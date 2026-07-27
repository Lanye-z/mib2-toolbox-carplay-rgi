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

APP_SOURCE="${VOLUME}/Toolbox/apps/carplay-rgi"
HOOK_TARGET="/mnt/app/root/hooks"
JAR_TARGET="/mnt/app/eso/hmi/lsd/jars"
CONFIG_TARGET="/mnt/system/etc/eso/production"
SMARTPHONE_JSON="${CONFIG_TARGET}/smartphone_integrator.json"
DIO_JSON="${CONFIG_TARGET}/dio_manager.json"
BACKUPFOLDER="${VOLUME}/Backup/${VERSION}/${FAZIT}/CarPlayRGI"

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: Missing $1"
    mount -ur /mnt/app 2>/dev/null
    mount -ur /mnt/system 2>/dev/null
    exit 0
  fi
}

backup_file() {
  SRC="$1"
  FILENAME=$(basename "$SRC")

  if [ -f "${BACKUPFOLDER}/${FILENAME}" ]; then
    echo "Backup already exists for ${FILENAME}. Skipping..."
  else
    echo "Backing up ${SRC}"
    mkdir -p "${BACKUPFOLDER}"
    touch "${BACKUPFOLDER}/DONT_TOUCH_ANYTHING_HERE"
    cp -v "${SRC}" "${BACKUPFOLDER}/"
  fi
}

patch_smartphone_integrator() {
  if grep -q "LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so" "${SMARTPHONE_JSON}"; then
    echo "smartphone_integrator.json already contains CarPlay RGI LD_PRELOAD. Skipping..."
    return
  fi

  echo "Patching smartphone_integrator.json"
  awk '
    /IPL_CONFIG_DIR_DIO_MANAGER=\/etc\/eso\/production/ {
      if ($0 !~ /,[[:space:]]*$/) sub(/"[[:space:]]*$/, "\",");
      print;
      print "        \"LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so\"";
      next;
    }
    { print }
  ' "${SMARTPHONE_JSON}" > "${SMARTPHONE_JSON}.carplay-rgi.tmp" && mv "${SMARTPHONE_JSON}.carplay-rgi.tmp" "${SMARTPHONE_JSON}"
}

patch_dio_message() {
  FILE="$1"
  KEY="$2"
  VALUE="$3"

  if grep -q "${VALUE}" "${FILE}"; then
    echo "${KEY} already contains ${VALUE}. Skipping..."
    return
  fi

  echo "Adding ${VALUE} to ${KEY}"
  sed -i "/\"${KEY}\"/ s/]/, \"${VALUE}\"]/" "${FILE}"
}

require_file "${APP_SOURCE}/libcarplay_hook.so"
require_file "${APP_SOURCE}/maneuver_render"
require_file "${APP_SOURCE}/flag_atlas.rgba"
require_file "${APP_SOURCE}/carplay_hook.jar"
require_file "${SMARTPHONE_JSON}"
require_file "${DIO_JSON}"

mount -uw /mnt/app
mount -uw /mnt/system

backup_file "${SMARTPHONE_JSON}"
backup_file "${DIO_JSON}"

mkdir -p "${HOOK_TARGET}"
mkdir -p "${JAR_TARGET}"
chmod 755 "${HOOK_TARGET}"

echo "Copying CarPlay RGI files"
cp -v "${APP_SOURCE}/libcarplay_hook.so" "${HOOK_TARGET}/libcarplay_hook.so"
cp -v "${APP_SOURCE}/maneuver_render" "${HOOK_TARGET}/maneuver_render"
cp -v "${APP_SOURCE}/flag_atlas.rgba" "${HOOK_TARGET}/flag_atlas.rgba"
cp -v "${APP_SOURCE}/carplay_hook.jar" "${JAR_TARGET}/carplay_hook.jar"
chmod 755 "${HOOK_TARGET}/libcarplay_hook.so"
chmod 755 "${HOOK_TARGET}/maneuver_render"
chmod 644 "${HOOK_TARGET}/flag_atlas.rgba"
chmod 644 "${JAR_TARGET}/carplay_hook.jar"

patch_smartphone_integrator
patch_dio_message "${DIO_JSON}" "MessagesSentByAccessory" "0x5200"
patch_dio_message "${DIO_JSON}" "MessagesSentByAccessory" "0x5203"
patch_dio_message "${DIO_JSON}" "MessagesReceivedFromDevice" "0x5201"
patch_dio_message "${DIO_JSON}" "MessagesReceivedFromDevice" "0x5202"
patch_dio_message "${DIO_JSON}" "MessagesReceivedFromDevice" "0x5204"

sync
sleep 1
mount -ur /mnt/app
mount -ur /mnt/system

echo "CarPlay Route Guidance Interface installed."
echo "Backup is stored at Backup/${VERSION}/${FAZIT}/CarPlayRGI"
echo "Please wait at least 30 seconds, then reboot the headunit."

exit 0
