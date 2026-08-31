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

APP_SOURCE="${VOLUME}/Toolbox/apps/carplay-rgi-new"
HOOK_TARGET="/mnt/app/root/hooks"
JAR_TARGET="/mnt/app/eso/hmi/lsd/jars"
CONFIG_TARGET="/mnt/system/etc/eso/production"
SMARTPHONE_JSON="${CONFIG_TARGET}/smartphone_integrator.json"
DIO_JSON="${CONFIG_TARGET}/dio_manager.json"

OLD_BACKUPFOLDER="${VOLUME}/Backup/${VERSION}/CarPlayRGI"
BACKUPFOLDER="${VOLUME}/Backup/${VERSION}/CarPlayRGI-new"
LOGFILE="${BACKUPFOLDER}/install_carplay_rgi_new.log"
TXN_DIR="${BACKUPFOLDER}/.install_transaction"

TXN_ACTIVE=0
ROLLING_BACK=0
DETECTED_STATE="UNKNOWN"

exec 3>&1
mkdir -p "${BACKUPFOLDER}" || exit 1
touch "${BACKUPFOLDER}/DONT_TOUCH_ANYTHING_HERE" || exit 1
touch "${LOGFILE}" || exit 1
exec >> "${LOGFILE}" 2>&1

log() {
  echo "$*"
  echo "$*" >&3
}

remount_read_only() {
  RO_RESULT=0
  mount -ur /mnt/app 2>/dev/null || RO_RESULT=1
  mount -ur /mnt/system 2>/dev/null || RO_RESULT=1
  return "${RO_RESULT}"
}

require_file() {
  if [ ! -f "$1" ]; then
    fail "Missing $1"
  fi
}

require_source_file() {
  if [ ! -f "$1" ]; then
    fail "Missing source file $1"
  fi
  set -- `ls -l "$1" 2>/dev/null`
  case "${5:-0}" in
    ''|*[!0-9]*) fail "Could not determine source file size: $1" ;;
  esac
  if [ "${5:-0}" -le 0 ]; then
    fail "Source file is empty: $1"
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

  rm -f "${TARGET}.carplay-rgi-new.rollback.tmp" 2>/dev/null

  if [ -f "${TXN_DIR}/${LABEL}.present" ]; then
    if cp "${TXN_DIR}/${LABEL}" "${TARGET}.carplay-rgi-new.rollback.tmp" && \
       chmod "${MODE}" "${TARGET}.carplay-rgi-new.rollback.tmp" && \
       mv "${TARGET}.carplay-rgi-new.rollback.tmp" "${TARGET}"
    then
      log "Rollback restored ${TARGET}"
      return 0
    fi
    log "ROLLBACK ERROR: Could not restore ${TARGET}"
    return 1
  fi

  if rm -f "${TARGET}"; then
    log "Rollback removed newly installed ${TARGET}"
    return 0
  fi

  log "ROLLBACK ERROR: Could not remove ${TARGET}"
  return 1
}

restore_backup_artifact() {
  LABEL="$1"
  TARGET="$2"

  rm -f "${TARGET}.carplay-rgi-new.rollback.tmp" 2>/dev/null
  if [ -f "${TXN_DIR}/${LABEL}.present" ]; then
    if cp "${TXN_DIR}/${LABEL}" "${TARGET}.carplay-rgi-new.rollback.tmp" && \
       mv "${TARGET}.carplay-rgi-new.rollback.tmp" "${TARGET}"
    then
      return 0
    fi
    return 1
  fi
  rm -f "${TARGET}"
}

rollback_installation() {
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

  restore_backup_artifact "smartphone_integrator_new.json" "${BACKUPFOLDER}/smartphone_integrator_new.json" || RESULT=1
  restore_backup_artifact "dio_manager_new.json" "${BACKUPFOLDER}/dio_manager_new.json" || RESULT=1

  if [ -f "${TXN_DIR}/hook_dir_absent" ]; then
    rmdir "${HOOK_TARGET}" 2>/dev/null || true
  fi
  if [ -f "${TXN_DIR}/jar_dir_absent" ]; then
    rmdir "${JAR_TARGET}" 2>/dev/null || true
  fi

  sync 2>/dev/null || RESULT=1
  remount_read_only || RESULT=1

  if [ "${RESULT}" -eq 0 ]; then
    TXN_ACTIVE=0
    rm -rf "${TXN_DIR}" 2>/dev/null || true
    log "Rollback completed; pre-install state restored"
  else
    log "ROLLBACK INCOMPLETE: transaction snapshot retained at ${TXN_DIR}"
  fi

  ROLLING_BACK=0
  return "${RESULT}"
}

fail() {
  FAILURE_MESSAGE="$*"
  log "ERROR: ${FAILURE_MESSAGE}"

  if [ "${TXN_ACTIVE}" -eq 1 ] || [ -f "${TXN_DIR}/active" ]; then
    rollback_installation
    ROLLBACK_STATUS=$?
  else
    ROLLBACK_STATUS=0
    remount_read_only 2>/dev/null || true
  fi

  if [ "${ROLLBACK_STATUS}" -eq 0 ]; then
    log "Installation aborted safely. See ${LOGFILE}"
  else
    log "Installation aborted, but rollback was incomplete. Do not reboot; inspect ${LOGFILE} and ${TXN_DIR}"
  fi
  exit 1
}

begin_transaction() {
  if [ -d "${TXN_DIR}" ]; then
    fail "Transaction directory already exists: ${TXN_DIR}"
  fi

  log "Creating pre-install transaction snapshot"
  mkdir "${TXN_DIR}" || fail "Could not create ${TXN_DIR}"

  snapshot_file "${SMARTPHONE_JSON}" "smartphone_integrator.json"
  snapshot_file "${DIO_JSON}" "dio_manager.json"

  snapshot_file "${HOOK_TARGET}/carplay_startup.sh" "carplay_startup.sh"
  snapshot_file "${HOOK_TARGET}/carplay_cleanup.sh" "carplay_cleanup.sh"
  snapshot_file "${HOOK_TARGET}/carplay_processes.sh" "carplay_processes.sh"
  snapshot_file "${HOOK_TARGET}/libcarplay_hook.so" "libcarplay_hook.so"
  snapshot_file "${HOOK_TARGET}/maneuver_render" "maneuver_render"
  snapshot_file "${HOOK_TARGET}/flag_atlas.rgba" "flag_atlas.rgba"
  snapshot_file "${JAR_TARGET}/carplay_hook.jar" "carplay_hook.jar"

  snapshot_file "${BACKUPFOLDER}/smartphone_integrator_new.json" "smartphone_integrator_new.json"
  snapshot_file "${BACKUPFOLDER}/dio_manager_new.json" "dio_manager_new.json"

  if [ ! -d "${HOOK_TARGET}" ]; then
    touch "${TXN_DIR}/hook_dir_absent" || fail "Could not record hooks directory state"
  fi
  if [ ! -d "${JAR_TARGET}" ]; then
    touch "${TXN_DIR}/jar_dir_absent" || fail "Could not record jars directory state"
  fi

  touch "${TXN_DIR}/active" || fail "Could not activate transaction"
  TXN_ACTIVE=1
  log "Transaction snapshot ready"
}

recover_stale_transaction() {
  if [ ! -d "${TXN_DIR}" ]; then
    return
  fi

  if [ -f "${TXN_DIR}/committed" ]; then
    log "Removing transaction snapshot left after completed installation"
    rm -rf "${TXN_DIR}" || fail "Could not remove completed transaction snapshot"
    return
  fi

  if [ ! -f "${TXN_DIR}/active" ]; then
    log "Removing incomplete transaction directory created before production changes"
    rm -rf "${TXN_DIR}" || fail "Could not remove incomplete transaction directory"
    return
  fi

  log "Detected interrupted previous installation; restoring pre-install state"
  TXN_ACTIVE=1
  if ! rollback_installation; then
    fail "Could not recover interrupted previous installation"
  fi
  trap 'fail "Installation interrupted by signal"' 1 2 15
}

# Output:
# <carplay object count> <old LD_PRELOAD count> <new exec count>
# <new hook path count> <new cleanup count> <DIO env marker count>
carplay_object_stats() {
  FILE="$1"
  awk '
    function brace_delta(s, start,    i,c,q,e,d) {
      for (i=start; i<=length(s); i++) {
        c=substr(s,i,1)
        if (q) {
          if (e) e=0
          else if (c=="\\") e=1
          else if (c=="\"") q=0
        } else if (c=="\"") q=1
        else if (c=="{") d++
        else if (c=="}") d--
      }
      return d
    }
    function count_token(s,t,    p,n,r) {
      r=s
      while ((p=index(r,t)) > 0) { n++; r=substr(r,p+length(t)) }
      return n
    }
    /^[ \t]*#/ { next }
    {
      line=$0
      if (!active && !pending) {
        kp=index(line,"\"carplay\"")
        if (kp>0 && substr(line,kp+length("\"carplay\"")) ~ /^[ \t]*:/) {
          pending=1
          objects++
          search=kp
        }
      } else search=1

      if (pending && !active) {
        op=index(substr(line,search),"{")
        if (op>0) {
          start=search+op-1
          active=1
          pending=0
          depth=0
        } else next
      } else if (active) start=1

      if (active) {
        old += count_token(line,"LD_PRELOAD=/mnt/app/root/hooks/libcarplay_hook.so")
        dioenv += count_token(line,"IPL_CONFIG_DIR_DIO_MANAGER=/etc/eso/production")
        if (line ~ /"exec"[ \t]*:[ \t]*"carplay_startup\.sh"/) newexec++
        if (line ~ /"path"[ \t]*:[ \t]*"\/mnt\/app\/root\/hooks"/) newpath++
        if (line ~ /"cleanupScript"[ \t]*:[ \t]*"\/mnt\/app\/root\/hooks\/carplay_cleanup\.sh"/) newcleanup++

        depth += brace_delta(line,start)
        if (depth==0) {
          active=0
          start=1
        }
      }
    }
    END { print objects+0, old+0, newexec+0, newpath+0, newcleanup+0, dioenv+0 }
  ' "${FILE}"
}

# Output: <matching array count> <value count in those arrays>
array_stats() {
  FILE="$1"
  KEY="$2"
  VALUE="$3"
  awk -v key="\"${KEY}\"" -v value="\"${VALUE}\"" '
    function scan_array(s,start,    i,c,q,e) {
      for (i=start; i<=length(s); i++) {
        c=substr(s,i,1)
        if (q) {
          if (e) e=0
          else if (c=="\\") e=1
          else if (c=="\"") q=0
        } else if (c=="\"") q=1
        else if (c=="[") depth++
        else if (c=="]") {
          depth--
          if (depth==0) { active=0; return i }
        }
      }
      return 0
    }
    function count_value(s,    p,r) {
      r=s
      while ((p=index(r,value)) > 0) { values++; r=substr(r,p+length(value)) }
    }
    /^[ \t]*#/ { next }
    {
      line=$0
      if (!active && !pending) {
        kp=index(line,key)
        if (kp>0 && substr(line,kp+length(key)) ~ /^[ \t]*:/) {
          pending=1
          arrays++
          search=kp
        }
      } else search=1

      if (pending && !active) {
        op=index(substr(line,search),"[")
        if (op>0) {
          start=search+op-1
          active=1
          pending=0
          depth=0
        }
      } else if (active) start=1

      if (active) {
        close_at=scan_array(line,start)
        if (close_at>0) count_value(substr(line,start,close_at-start+1))
        else count_value(substr(line,start))
      }
    }
    END { print arrays+0, values+0 }
  ' "${FILE}"
}

classify_state() {
  SP="$1"
  DJ="$2"

  if [ ! -f "${SP}" ] || [ ! -f "${DJ}" ]; then
    echo "INVALID"
    return
  fi

  set -- `carplay_object_stats "${SP}"`
  OBJECTS=$1
  OLD_PRELOAD=$2
  NEW_EXEC=$3
  NEW_PATH=$4
  NEW_CLEANUP=$5
  DIO_ENV=$6

  if [ "${OBJECTS}" -ne 1 ] || [ "${DIO_ENV}" -ne 1 ]; then
    echo "INVALID"
    return
  fi

  if [ "${OLD_PRELOAD}" -gt 1 ] || [ "${NEW_EXEC}" -gt 1 ] || \
     [ "${NEW_PATH}" -gt 1 ] || [ "${NEW_CLEANUP}" -gt 1 ]; then
    echo "INVALID"
    return
  fi

  RG_COUNT=0
  for ITEM in \
    "MessagesSentByAccessory:0x5200" \
    "MessagesSentByAccessory:0x5203" \
    "MessagesReceivedFromDevice:0x5201" \
    "MessagesReceivedFromDevice:0x5202" \
    "MessagesReceivedFromDevice:0x5204"
  do
    KEY=${ITEM%%:*}
    VALUE=${ITEM#*:}
    set -- `array_stats "${DJ}" "${KEY}" "${VALUE}"`
    if [ "$1" -ne 1 ] || [ "$2" -gt 1 ]; then
      echo "INVALID"
      return
    fi
    RG_COUNT=`expr "${RG_COUNT}" + "$2"`
  done

  if [ "${OLD_PRELOAD}" -eq 0 ] && [ "${NEW_EXEC}" -eq 0 ] && \
     [ "${NEW_PATH}" -eq 0 ] && [ "${NEW_CLEANUP}" -eq 0 ] && [ "${RG_COUNT}" -eq 0 ]; then
    echo "CLEAN"
    return
  fi

  if [ "${OLD_PRELOAD}" -eq 1 ] && [ "${NEW_EXEC}" -eq 0 ] && \
     [ "${NEW_PATH}" -eq 0 ] && [ "${NEW_CLEANUP}" -eq 0 ] && [ "${RG_COUNT}" -eq 5 ]; then
    echo "OLD"
    return
  fi

  if [ "${OLD_PRELOAD}" -eq 0 ] && [ "${NEW_EXEC}" -eq 1 ] && \
     [ "${NEW_PATH}" -eq 1 ] && [ "${NEW_CLEANUP}" -eq 1 ] && [ "${RG_COUNT}" -eq 5 ]; then
    echo "NEW"
    return
  fi

  echo "INVALID"
}

validate_stock_pair() {
  SP="$1"
  DJ="$2"
  LABEL="$3"

  STATE=`classify_state "${SP}" "${DJ}"`
  if [ "${STATE}" != "CLEAN" ]; then
    fail "${LABEL} is not a clean stock configuration (detected ${STATE})"
  fi
  log "${LABEL} validated as clean stock"
}

backup_stock_if_missing() {
  if [ -f "${BACKUPFOLDER}/smartphone_integrator.json" ] || \
     [ -f "${BACKUPFOLDER}/dio_manager.json" ]; then
    if [ ! -f "${BACKUPFOLDER}/smartphone_integrator.json" ] || \
       [ ! -f "${BACKUPFOLDER}/dio_manager.json" ]; then
      fail "CarPlayRGI-new stock backup is incomplete; refusing to overwrite it"
    fi
    validate_stock_pair \
      "${BACKUPFOLDER}/smartphone_integrator.json" \
      "${BACKUPFOLDER}/dio_manager.json" \
      "Existing CarPlayRGI-new stock backup"
    return
  fi

  log "Creating CarPlayRGI-new stock configuration backup"
  cp "${SMARTPHONE_JSON}" "${BACKUPFOLDER}/smartphone_integrator.json" || \
    fail "Could not back up ${SMARTPHONE_JSON}"
  cp "${DIO_JSON}" "${BACKUPFOLDER}/dio_manager.json" || \
    fail "Could not back up ${DIO_JSON}"

  validate_stock_pair \
    "${BACKUPFOLDER}/smartphone_integrator.json" \
    "${BACKUPFOLDER}/dio_manager.json" \
    "New CarPlayRGI-new stock backup"
}

restore_old_to_stock() {
  log "Old CarPlayRGI installation detected; restoring its original stock backup first"

  require_file "${OLD_BACKUPFOLDER}/smartphone_integrator.json"
  require_file "${OLD_BACKUPFOLDER}/dio_manager.json"
  validate_stock_pair \
    "${OLD_BACKUPFOLDER}/smartphone_integrator.json" \
    "${OLD_BACKUPFOLDER}/dio_manager.json" \
    "Legacy CarPlayRGI stock backup"

  cp "${OLD_BACKUPFOLDER}/smartphone_integrator.json" "${SMARTPHONE_JSON}.carplay-rgi-new.tmp" || \
    fail "Could not stage stock smartphone_integrator.json"
  chmod 644 "${SMARTPHONE_JSON}.carplay-rgi-new.tmp" || fail "Could not chmod stock smartphone_integrator.json"
  mv "${SMARTPHONE_JSON}.carplay-rgi-new.tmp" "${SMARTPHONE_JSON}" || fail "Could not restore stock smartphone_integrator.json"

  cp "${OLD_BACKUPFOLDER}/dio_manager.json" "${DIO_JSON}.carplay-rgi-new.tmp" || \
    fail "Could not stage stock dio_manager.json"
  chmod 644 "${DIO_JSON}.carplay-rgi-new.tmp" || fail "Could not chmod stock dio_manager.json"
  mv "${DIO_JSON}.carplay-rgi-new.tmp" "${DIO_JSON}" || fail "Could not restore stock dio_manager.json"

  rm -f "${HOOK_TARGET}/libcarplay_hook.so" \
        "${HOOK_TARGET}/maneuver_render" \
        "${HOOK_TARGET}/flag_atlas.rgba" \
        "${JAR_TARGET}/carplay_hook.jar" || \
    fail "Could not remove legacy CarPlayRGI runtime files"

  STATE=`classify_state "${SMARTPHONE_JSON}" "${DIO_JSON}"`
  if [ "${STATE}" != "CLEAN" ]; then
    fail "Legacy restore did not return production configuration to CLEAN state"
  fi

  log "Legacy CarPlayRGI restored to stock successfully"
}

replace_carplay_object() {
  TEMPLATE="$1"
  TMP="${SMARTPHONE_JSON}.carplay-rgi-new.tmp"

  log "Replacing children.carplay with supervisor configuration"

  awk -v tplfile="${TEMPLATE}" '
    BEGIN {
      while ((getline t < tplfile) > 0) tpl[++tn]=t
      close(tplfile)
      if (tn < 2) exit 3
    }
    function leading_ws(s) {
      match(s,/^[ \t]*/)
      return substr(s,1,RLENGTH)
    }
    function scan_object(s,start,    i,c,q,e) {
      for (i=start; i<=length(s); i++) {
        c=substr(s,i,1)
        if (q) {
          if (e) e=0
          else if (c=="\\") e=1
          else if (c=="\"") q=0
        } else if (c=="\"") q=1
        else if (c=="{") depth++
        else if (c=="}") {
          depth--
          if (depth==0) return i
        }
      }
      return 0
    }
    function emit_template(has_comma,    i,last) {
      print indent "\"carplay\": " tpl[1]
      for (i=2; i<tn; i++) print indent tpl[i]
      last=indent tpl[tn]
      if (has_comma) last=last ","
      print last
    }
    {
      line=$0

      if (active) {
        if (line !~ /^[ \t]*#/) {
          close_at=scan_object(line,1)
          if (close_at>0) {
            tail=substr(line,close_at+1)
            emit_template(tail ~ /,/)
            active=0
            replaced++
          }
        }
        next
      }

      if (pending) {
        if (line ~ /^[ \t]*#/) next
        op=index(line,"{")
        if (op>0) {
          active=1
          pending=0
          depth=0
          close_at=scan_object(line,op)
          if (close_at>0) {
            tail=substr(line,close_at+1)
            emit_template(tail ~ /,/)
            active=0
            replaced++
          }
        }
        next
      }

      if (line ~ /^[ \t]*"carplay"[ \t]*:/) {
        indent=leading_ws(line)
        colon=index(line,":")
        rest=substr(line,colon+1)
        op=index(rest,"{")
        if (op>0) {
          absolute=colon+op
          active=1
          depth=0
          close_at=scan_object(line,absolute)
          if (close_at>0) {
            tail=substr(line,close_at+1)
            emit_template(tail ~ /,/)
            active=0
            replaced++
          }
        } else pending=1
        next
      }

      print line
    }
    END {
      if (replaced != 1 || active || pending) exit 2
    }
  ' "${SMARTPHONE_JSON}" > "${TMP}" || fail "Could not replace children.carplay"

  chmod 644 "${TMP}" || fail "Could not chmod patched smartphone_integrator.json"
  mv "${TMP}" "${SMARTPHONE_JSON}" || fail "Could not install patched smartphone_integrator.json"
}

append_json_array_value() {
  FILE="$1"
  KEY="$2"
  VALUE="$3"
  TMP="${FILE}.carplay-rgi-new.tmp"

  set -- `array_stats "${FILE}" "${KEY}" "${VALUE}"`
  if [ "$1" -ne 1 ]; then
    fail "Expected exactly one ${KEY} array"
  fi
  if [ "$2" -eq 1 ]; then
    log "${VALUE} already present in ${KEY}; skipping"
    return
  fi
  if [ "$2" -ne 0 ]; then
    fail "Duplicate ${VALUE} detected in ${KEY}"
  fi

  awk -v key="\"${KEY}\"" -v value="${VALUE}" '
    function find_close(s,start,    i,c,q,e) {
      for (i=start; i<=length(s); i++) {
        c=substr(s,i,1)
        if (q) {
          if (e) e=0
          else if (c=="\\") e=1
          else if (c=="\"") q=0
        } else if (c=="\"") { q=1; has_element=1 }
        else if (c=="[") depth++
        else if (c=="]") {
          depth--
          if (depth==0) return i
        }
      }
      return 0
    }
    function leading_ws(s) {
      match(s,/^[ \t]*/)
      return substr(s,1,RLENGTH)
    }
    function nonblank(s) { return s ~ /[^ \t]/ }
    function element_line(s,first,    part,p) {
      part=s
      if (first) {
        p=index(part,"[")
        if (p>0) part=substr(part,p+1)
      }
      return index(part,"\"")>0
    }
    function add_comma(s,    t,ws) {
      match(s,/[ \t]*$/)
      ws=substr(s,RSTART)
      t=substr(s,1,RSTART-1)
      if (t !~ /,$/) t=t ","
      return t ws
    }
    function flush_multiline(close_at,    prefix,suffix,close_ws,content_n,last,i,indent2) {
      prefix=substr(buf[buf_n],1,close_at-1)
      suffix=substr(buf[buf_n],close_at)
      close_ws=leading_ws(buf[buf_n])

      if (nonblank(prefix)) {
        buf[buf_n]=prefix
        content_n=buf_n
        close_line=close_ws suffix
      } else {
        content_n=buf_n-1
        close_line=buf[buf_n]
      }

      last=0
      for (i=content_n; i>=1; i--) {
        if (element_line(buf[i],i==1)) { last=i; break }
      }

      if (last>0) {
        buf[last]=add_comma(buf[last])
        indent2=leading_ws(buf[last])
        if (last==1) indent2=close_ws "    "
      } else indent2=close_ws "    "

      for (i=1; i<=content_n; i++) print buf[i]
      print indent2 "\"" value "\""
      print close_line

      delete buf
      buf_n=0
    }
    {
      line=$0

      if (active && multiline) {
        buf[++buf_n]=line
        if (line !~ /^[ \t]*#/) {
          close_at=find_close(line,1)
          if (close_at>0) {
            flush_multiline(close_at)
            active=0
            multiline=0
            patched++
          }
        }
        next
      }

      if (line ~ /^[ \t]*#/) { print line; next }

      if (!active && !pending) {
        kp=index(line,key)
        if (kp>0 && substr(line,kp+length(key)) ~ /^[ \t]*:/) {
          pending=1
          search=kp
        }
      } else search=1

      if (pending && !active) {
        op=index(substr(line,search),"[")
        if (op>0) {
          start=search+op-1
          active=1
          pending=0
          depth=0
          has_element=0
          close_at=find_close(line,start)

          if (close_at>0) {
            addition="\"" value "\""
            if (has_element) addition=", " addition
            line=substr(line,1,close_at-1) addition substr(line,close_at)
            active=0
            patched++
          } else {
            multiline=1
            buf[++buf_n]=line
            next
          }
        }
      }

      print line
    }
    END {
      if (patched != 1 || active || pending) exit 2
    }
  ' "${FILE}" > "${TMP}" || fail "Could not add ${VALUE} to ${KEY}"

  chmod 644 "${TMP}" || fail "Could not chmod patched $(basename "${FILE}")"
  mv "${TMP}" "${FILE}" || fail "Could not replace $(basename "${FILE}")"

  set -- `array_stats "${FILE}" "${KEY}" "${VALUE}"`
  if [ "$1" -ne 1 ] || [ "$2" -ne 1 ]; then
    fail "Verification failed for ${KEY} ${VALUE}"
  fi
}

patch_dio_manager() {
  log "Ensuring all five CarPlay RGI message IDs are registered"

  append_json_array_value "${DIO_JSON}" "MessagesSentByAccessory" "0x5200"
  append_json_array_value "${DIO_JSON}" "MessagesSentByAccessory" "0x5203"
  append_json_array_value "${DIO_JSON}" "MessagesReceivedFromDevice" "0x5201"
  append_json_array_value "${DIO_JSON}" "MessagesReceivedFromDevice" "0x5202"
  append_json_array_value "${DIO_JSON}" "MessagesReceivedFromDevice" "0x5204"
}

copy_component() {
  SOURCE="$1"
  TARGET="$2"
  MODE="$3"
  TMP="${TARGET}.carplay-rgi-new.tmp"

  cp -v "${SOURCE}" "${TMP}" || fail "Could not copy $(basename "${SOURCE}")"
  chmod "${MODE}" "${TMP}" || fail "Could not chmod $(basename "${TARGET}")"
  mv "${TMP}" "${TARGET}" || fail "Could not install $(basename "${TARGET}")"
}

save_modified_copy() {
  SOURCE="$1"
  TARGET="$2"
  TMP="${TARGET}.carplay-rgi-new.tmp"

  cp "${SOURCE}" "${TMP}" || fail "Could not stage $(basename "${TARGET}")"
  chmod 644 "${TMP}" || fail "Could not chmod $(basename "${TARGET}")"
  mv "${TMP}" "${TARGET}" || fail "Could not save $(basename "${TARGET}")"
}

verify_installation() {
  for TARGET in \
    "${HOOK_TARGET}/carplay_startup.sh" \
    "${HOOK_TARGET}/carplay_cleanup.sh" \
    "${HOOK_TARGET}/carplay_processes.sh" \
    "${HOOK_TARGET}/libcarplay_hook.so" \
    "${HOOK_TARGET}/maneuver_render" \
    "${HOOK_TARGET}/flag_atlas.rgba" \
    "${JAR_TARGET}/carplay_hook.jar"
  do
    require_file "${TARGET}"
  done

  STATE=`classify_state "${SMARTPHONE_JSON}" "${DIO_JSON}"`
  if [ "${STATE}" != "NEW" ]; then
    fail "Post-install configuration verification failed (detected ${STATE}, expected NEW)"
  fi

  log "Installed configuration verified as NEW"
}

trap 'fail "Installation interrupted by signal"' 1 2 15

log "===== CarPlay RGI New installation started ====="
date
log "Firmware: ${VERSION}"
log "FAZIT: ${FAZIT}"
log "Source: ${APP_SOURCE}"
log "Backup: ${BACKUPFOLDER}"

recover_stale_transaction

require_file "${SMARTPHONE_JSON}"
require_file "${DIO_JSON}"
require_source_file "${APP_SOURCE}/carplay_startup.sh"
require_source_file "${APP_SOURCE}/carplay_cleanup.sh"
require_source_file "${APP_SOURCE}/carplay_processes.sh"
require_source_file "${APP_SOURCE}/carplay_child.json"
require_source_file "${APP_SOURCE}/libcarplay_hook.so"
require_source_file "${APP_SOURCE}/maneuver_render"
require_source_file "${APP_SOURCE}/flag_atlas.rgba"
require_source_file "${APP_SOURCE}/carplay_hook.jar"

DETECTED_STATE=`classify_state "${SMARTPHONE_JSON}" "${DIO_JSON}"`
log "Detected production state: ${DETECTED_STATE}"

case "${DETECTED_STATE}" in
  CLEAN)
    log "Clean stock state: first CarPlayRGI-new installation"
    ;;
  OLD)
    log "Legacy CarPlayRGI state: stock restore will be performed before NEW installation"
    ;;
  NEW)
    if [ ! -f "${BACKUPFOLDER}/smartphone_integrator.json" ] || \
       [ ! -f "${BACKUPFOLDER}/dio_manager.json" ]; then
      fail "NEW installation detected but CarPlayRGI-new stock backup is missing"
    fi
    validate_stock_pair \
      "${BACKUPFOLDER}/smartphone_integrator.json" \
      "${BACKUPFOLDER}/dio_manager.json" \
      "CarPlayRGI-new stock backup"
    log "Existing NEW installation: safe overwrite/update"
    ;;
  *)
    fail "Unsupported mixed/partial CarPlay RGI state. Restore to a known CLEAN, OLD, or NEW state before retrying"
    ;;
esac

begin_transaction

log "Mounting /mnt/app and /mnt/system read-write"
mount -uw /mnt/app || fail "Could not mount /mnt/app read-write"
mount -uw /mnt/system || fail "Could not mount /mnt/system read-write"

mkdir -p "${HOOK_TARGET}" || fail "Could not create ${HOOK_TARGET}"
mkdir -p "${JAR_TARGET}" || fail "Could not create ${JAR_TARGET}"
chmod 755 "${HOOK_TARGET}" || fail "Could not set permissions on ${HOOK_TARGET}"

if [ "${DETECTED_STATE}" = "OLD" ]; then
  restore_old_to_stock
fi

if [ "${DETECTED_STATE}" = "CLEAN" ] || [ "${DETECTED_STATE}" = "OLD" ]; then
  STATE=`classify_state "${SMARTPHONE_JSON}" "${DIO_JSON}"`
  if [ "${STATE}" != "CLEAN" ]; then
    fail "Expected CLEAN state before creating CarPlayRGI-new stock backup"
  fi
  backup_stock_if_missing
fi

log "Installing CarPlay RGI New supervisor and runtime files"
copy_component "${APP_SOURCE}/carplay_startup.sh" "${HOOK_TARGET}/carplay_startup.sh" 755
copy_component "${APP_SOURCE}/carplay_cleanup.sh" "${HOOK_TARGET}/carplay_cleanup.sh" 755
copy_component "${APP_SOURCE}/carplay_processes.sh" "${HOOK_TARGET}/carplay_processes.sh" 755
copy_component "${APP_SOURCE}/libcarplay_hook.so" "${HOOK_TARGET}/libcarplay_hook.so" 755
copy_component "${APP_SOURCE}/maneuver_render" "${HOOK_TARGET}/maneuver_render" 755
copy_component "${APP_SOURCE}/flag_atlas.rgba" "${HOOK_TARGET}/flag_atlas.rgba" 644
copy_component "${APP_SOURCE}/carplay_hook.jar" "${JAR_TARGET}/carplay_hook.jar" 644

replace_carplay_object "${APP_SOURCE}/carplay_child.json"
patch_dio_manager

verify_installation

save_modified_copy "${SMARTPHONE_JSON}" "${BACKUPFOLDER}/smartphone_integrator_new.json"
save_modified_copy "${DIO_JSON}" "${BACKUPFOLDER}/dio_manager_new.json"

log "Synchronizing filesystem changes"
sync || fail "sync failed"
sleep 2
remount_read_only || fail "Could not remount /mnt/app and /mnt/system read-only"

touch "${TXN_DIR}/committed" || fail "Could not mark transaction committed"
TXN_ACTIVE=0
rm -rf "${TXN_DIR}" || fail "Could not remove committed transaction snapshot"
trap - 1 2 15

log "CarPlay Route Guidance Interface New installed successfully."
log "Original stock backup: Backup/${VERSION}/CarPlayRGI-new/"
log "Installation log: Backup/${VERSION}/CarPlayRGI-new/install_carplay_rgi_new.log"
log "Please wait at least 30 seconds, then reboot the headunit."
log "===== CarPlay RGI New installation finished ====="
exit 0
