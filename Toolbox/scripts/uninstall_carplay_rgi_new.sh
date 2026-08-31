#!/bin/sh
export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/media/gracenote/bin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH

if [ "$_" = "/bin/on" ]; then BASE="$0"; else BASE="$_"; fi
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$BASE")")" && pwd -P )

. "${SCRIPTDIR}/util_info.sh"
. "${SCRIPTDIR}/util_mountsd.sh"
if [ -z "$VOLUME" ]; then
  echo "No SD-card found, quitting"
  exit 1
fi

HOOK_TARGET="/mnt/app/root/hooks"
JAR_TARGET="/mnt/app/eso/hmi/lsd/jars"
CONFIG_TARGET="/mnt/system/etc/eso/production"
SMARTPHONE_JSON="${CONFIG_TARGET}/smartphone_integrator.json"
DIO_JSON="${CONFIG_TARGET}/dio_manager.json"
BACKUPFOLDER="${VOLUME}/Backup/${VERSION}/CarPlayRGI-new"
LOGFILE="${BACKUPFOLDER}/uninstall_carplay_rgi_new.log"
TXN_DIR="${BACKUPFOLDER}/.uninstall_transaction"
TXN_ACTIVE=0
ROLLING_BACK=0

exec 3>&1
mkdir -p "${BACKUPFOLDER}" || exit 1
touch "${LOGFILE}" || exit 1
exec >> "${LOGFILE}" 2>&1

log() {
  echo "$*"
  echo "$*" >&3
}

remount_read_only() {
  RESULT=0
  mount -ur /mnt/app 2>/dev/null || RESULT=1
  mount -ur /mnt/system 2>/dev/null || RESULT=1
  return "${RESULT}"
}

fail() {
  MESSAGE="$*"
  log "ERROR: ${MESSAGE}"
  if [ "${TXN_ACTIVE}" -eq 1 ] || [ -f "${TXN_DIR}/active" ]; then
    rollback_uninstall
  else
    remount_read_only 2>/dev/null || true
  fi
  log "Uninstall log: Backup/${VERSION}/CarPlayRGI-new/uninstall_carplay_rgi_new.log"
  exit 1
}

require_backup() {
  if [ ! -f "$1" ]; then
    fail "Missing original stock backup $1"
  fi
}

snapshot_file() {
  TARGET="$1"
  LABEL="$2"
  if [ -f "${TARGET}" ]; then
    cp "${TARGET}" "${TXN_DIR}/${LABEL}" || fail "Could not snapshot ${TARGET}"
    touch "${TXN_DIR}/${LABEL}.present" || fail "Could not mark snapshot ${LABEL}"
  fi
}

restore_snapshot_file() {
  LABEL="$1"
  TARGET="$2"
  MODE="$3"
  TMP="${TARGET}.carplay-rgi-new.uninstall.rollback.tmp"

  rm -f "${TMP}" 2>/dev/null
  if [ -f "${TXN_DIR}/${LABEL}.present" ]; then
    cp "${TXN_DIR}/${LABEL}" "${TMP}" || return 1
    chmod "${MODE}" "${TMP}" || return 1
    mv "${TMP}" "${TARGET}" || return 1
    return 0
  fi
  rm -f "${TARGET}"
}

rollback_uninstall() {
  if [ "${ROLLING_BACK}" -eq 1 ]; then
    return 1
  fi
  ROLLING_BACK=1
  trap - 1 2 15
  RESULT=0

  log "Rollback started"
  mount -uw /mnt/app 2>/dev/null || RESULT=1
  mount -uw /mnt/system 2>/dev/null || RESULT=1

  restore_snapshot_file "smartphone_integrator.json" "${SMARTPHONE_JSON}" 644 || RESULT=1
  restore_snapshot_file "dio_manager.json" "${DIO_JSON}" 644 || RESULT=1
  restore_snapshot_file "carplay_startup.sh" "${HOOK_TARGET}/carplay_startup.sh" 755 || RESULT=1
  restore_snapshot_file "carplay_cleanup.sh" "${HOOK_TARGET}/carplay_cleanup.sh" 755 || RESULT=1
  restore_snapshot_file "carplay_processes.sh" "${HOOK_TARGET}/carplay_processes.sh" 755 || RESULT=1
  restore_snapshot_file "libcarplay_hook.so" "${HOOK_TARGET}/libcarplay_hook.so" 755 || RESULT=1
  restore_snapshot_file "maneuver_render" "${HOOK_TARGET}/maneuver_render" 755 || RESULT=1
  restore_snapshot_file "flag_atlas.rgba" "${HOOK_TARGET}/flag_atlas.rgba" 644 || RESULT=1
  restore_snapshot_file "carplay_hook.jar" "${JAR_TARGET}/carplay_hook.jar" 644 || RESULT=1

  sync 2>/dev/null || RESULT=1
  remount_read_only || RESULT=1

  if [ "${RESULT}" -eq 0 ]; then
    TXN_ACTIVE=0
    rm -rf "${TXN_DIR}" 2>/dev/null || true
    log "Rollback completed; pre-uninstall state restored"
  else
    log "ROLLBACK INCOMPLETE: transaction snapshot retained at ${TXN_DIR}"
  fi

  ROLLING_BACK=0
  return "${RESULT}"
}

begin_transaction() {
  if [ -d "${TXN_DIR}" ]; then
    fail "Uninstall transaction already exists: ${TXN_DIR}"
  fi
  mkdir "${TXN_DIR}" || fail "Could not create uninstall transaction"

  snapshot_file "${SMARTPHONE_JSON}" "smartphone_integrator.json"
  snapshot_file "${DIO_JSON}" "dio_manager.json"
  snapshot_file "${HOOK_TARGET}/carplay_startup.sh" "carplay_startup.sh"
  snapshot_file "${HOOK_TARGET}/carplay_cleanup.sh" "carplay_cleanup.sh"
  snapshot_file "${HOOK_TARGET}/carplay_processes.sh" "carplay_processes.sh"
  snapshot_file "${HOOK_TARGET}/libcarplay_hook.so" "libcarplay_hook.so"
  snapshot_file "${HOOK_TARGET}/maneuver_render" "maneuver_render"
  snapshot_file "${HOOK_TARGET}/flag_atlas.rgba" "flag_atlas.rgba"
  snapshot_file "${JAR_TARGET}/carplay_hook.jar" "carplay_hook.jar"

  touch "${TXN_DIR}/active" || fail "Could not activate uninstall transaction"
  TXN_ACTIVE=1
}

restore_stock_file() {
  SOURCE="$1"
  TARGET="$2"
  TMP="${TARGET}.carplay-rgi-new.uninstall.tmp"

  log "[restore] cp ${SOURCE} -> ${TMP}"
  cp "${SOURCE}" "${TMP}" || fail "Could not stage stock $(basename "${TARGET}")"
  chmod 644 "${TMP}" || fail "Could not chmod stock $(basename "${TARGET}")"
  mv "${TMP}" "${TARGET}" || fail "Could not restore stock $(basename "${TARGET}")"
  log "[restore] OK: ${SOURCE} -> ${TARGET}"
}

remove_component() {
  TARGET="$1"
  if [ -e "${TARGET}" ]; then
    log "Removing ${TARGET}"
    rm -f "${TARGET}" || fail "Could not remove ${TARGET}"
  else
    log "Component already absent: ${TARGET}"
  fi
}

# Minimal stock verification: the NEW supervisor markers and legacy LD_PRELOAD
# must be absent; the five RGI message IDs must be absent from dio_manager.json.
verify_stock_files() {
  SP="$1"
  DJ="$2"
  LABEL="$3"

  if grep 'LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so' "${SP}" >/dev/null 2>&1; then
    fail "${LABEL}: legacy LD_PRELOAD is present"
  fi
  if grep 'carplay_startup.sh' "${SP}" >/dev/null 2>&1; then
    fail "${LABEL}: NEW supervisor exec is present"
  fi
  if grep '/mnt/app/root/hooks/carplay_cleanup.sh' "${SP}" >/dev/null 2>&1; then
    fail "${LABEL}: NEW cleanupScript is present"
  fi

  for VALUE in 0x5200 0x5201 0x5202 0x5203 0x5204
  do
    if grep "\"${VALUE}\"" "${DJ}" >/dev/null 2>&1; then
      fail "${LABEL}: ${VALUE} is present"
    fi
  done
}

verify_stock() {
  verify_stock_files "${SMARTPHONE_JSON}" "${DIO_JSON}" "Restored production configuration"
}

trap 'fail "Uninstall interrupted by signal"' 1 2 15

log "===== CarPlay RGI New uninstall started ====="
date
log "Firmware: ${VERSION}"
log "FAZIT: ${FAZIT}"
log "Backup: ${BACKUPFOLDER}"

if [ -d "${TXN_DIR}" ]; then
  fail "Previous uninstall transaction exists. Inspect ${TXN_DIR} before retrying."
fi

require_backup "${BACKUPFOLDER}/smartphone_integrator.json"
require_backup "${BACKUPFOLDER}/dio_manager.json"
verify_stock_files \
  "${BACKUPFOLDER}/smartphone_integrator.json" \
  "${BACKUPFOLDER}/dio_manager.json" \
  "CarPlayRGI-new stock backup"

if grep 'LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so' "${SMARTPHONE_JSON}" >/dev/null 2>&1; then
  fail "Legacy CarPlayRGI installation detected. Use the legacy uninstaller or the NEW installer migration path instead."
fi

begin_transaction

log "Mounting /mnt/app and /mnt/system read-write"
mount -uw /mnt/app || fail "Could not mount /mnt/app read-write"
mount -uw /mnt/system || fail "Could not mount /mnt/system read-write"

restore_stock_file "${BACKUPFOLDER}/smartphone_integrator.json" "${SMARTPHONE_JSON}"
restore_stock_file "${BACKUPFOLDER}/dio_manager.json" "${DIO_JSON}"

log "Removing CarPlay RGI New files"
remove_component "${HOOK_TARGET}/carplay_startup.sh"
remove_component "${HOOK_TARGET}/carplay_cleanup.sh"
remove_component "${HOOK_TARGET}/carplay_processes.sh"
remove_component "${HOOK_TARGET}/libcarplay_hook.so"
remove_component "${HOOK_TARGET}/maneuver_render"
remove_component "${HOOK_TARGET}/flag_atlas.rgba"
remove_component "${JAR_TARGET}/carplay_hook.jar"

verify_stock

log "Synchronizing filesystem changes"
sync || fail "sync failed"
sleep 2
remount_read_only || fail "Could not remount /mnt/app and /mnt/system read-only"

TXN_ACTIVE=0
rm -rf "${TXN_DIR}" || fail "Could not remove uninstall transaction"
trap - 1 2 15

log "CarPlay Route Guidance Interface New restored to stock successfully."
log "Uninstall log: Backup/${VERSION}/CarPlayRGI-new/uninstall_carplay_rgi_new.log"
log "Please wait at least 30 seconds, then reboot the headunit."
log "===== CarPlay RGI New uninstall finished ====="
exit 0
