#!/usr/bin/env bash
source /vagrant/scripts/common.sh
sed_escape(){ printf '%s' "$1" | sed -e 's/[\\&/]/\\&/g'; }
dump_dbca_logs(){
  echo "Recent DBCA logs for diagnostics:"
  find "$ORACLE_BASE/cfgtoollogs/dbca" -maxdepth 4 -type f \( -name '*.log' -o -name '*.err' -o -name '*.out' \) -print -exec tail -n 80 {} \; 2>/dev/null || true
}
main(){
  oracle_env
  local oracle_user oracle_group sys system pdb timeout_minutes heartbeat_seconds dbca_pid heartbeat_pid dbca_rc
  oracle_user="$(json '.profile.oracle.user')"
  oracle_group="$(json '.profile.oracle.inventoryGroup')"
  timeout_minutes="$(json '.profile.oracle.databaseCreationTimeoutMinutes // 90')"
  heartbeat_seconds="$(json '.profile.oracle.databaseCreationHeartbeatSeconds // 120')"
  chmod 600 /vagrant/secrets.json
  sys=$(jq -r .oracleSysPassword /vagrant/secrets.json)
  system=$(jq -r .oracleSystemPassword /vagrant/secrets.json)
  pdb=$(jq -r .oraclePdbAdminPassword /vagrant/secrets.json)
  cp /vagrant/oracle/dbca.rsp.template /tmp/dbca.rsp
  sed -i "s/__SYS_PASSWORD__/$(sed_escape "$sys")/;s/__SYSTEM_PASSWORD__/$(sed_escape "$system")/;s/__PDB_PASSWORD__/$(sed_escape "$pdb")/" /tmp/dbca.rsp
  chown "$oracle_user:$oracle_group" /tmp/dbca.rsp
  chmod 600 /tmp/dbca.rsp
  echo "Starting DBCA with a ${timeout_minutes}-minute timeout; progress is streamed and a heartbeat prints every ${heartbeat_seconds} seconds."
  set +e
  runuser -u "$oracle_user" -- bash -lc "export ORACLE_BASE='$ORACLE_BASE' ORACLE_HOME='$ORACLE_HOME' ORACLE_SID='$ORACLE_SID' PATH='$ORACLE_HOME/bin':\$PATH; timeout --kill-after=5m '${timeout_minutes}m' dbca -silent -createDatabase -responseFile /tmp/dbca.rsp" &
  dbca_pid=$!
  (
    while kill -0 "$dbca_pid" >/dev/null 2>&1; do
      sleep "$heartbeat_seconds"
      kill -0 "$dbca_pid" >/dev/null 2>&1 || break
      echo "DBCA is still running at $(date -Is). If it remains at the same percentage for a long time, inspect /u01/app/oracle/cfgtoollogs/dbca/WCDEV from another shell."
    done
  ) &
  heartbeat_pid=$!
  wait "$dbca_pid"
  dbca_rc=$?
  kill "$heartbeat_pid" >/dev/null 2>&1 || true
  wait "$heartbeat_pid" >/dev/null 2>&1 || true
  set -e
  shred -u /tmp/dbca.rsp || rm -f /tmp/dbca.rsp
  if [[ $dbca_rc -eq 124 || $dbca_rc -eq 137 ]]; then
    echo "DBCA exceeded the configured ${timeout_minutes}-minute timeout. Increase profile.oracle.databaseCreationTimeoutMinutes only if the DBCA logs show active progress."
    dump_dbca_logs
    exit "$dbca_rc"
  elif [[ $dbca_rc -eq 6 ]]; then
    echo "DBCA completed with warnings (exit code 6). Verifying that the database is open before continuing."
    dump_dbca_logs
    verify_database_open "$oracle_user"
  elif [[ $dbca_rc -ne 0 ]]; then
    echo "DBCA failed with exit code $dbca_rc."
    dump_dbca_logs
    exit "$dbca_rc"
  fi
}
verify_database_open(){
  local oracle_user="$1"
  runuser -u "$oracle_user" -- bash -lc "export ORACLE_BASE='$ORACLE_BASE' ORACLE_HOME='$ORACLE_HOME' ORACLE_SID='$ORACLE_SID' PATH='$ORACLE_HOME/bin':\$PATH; sqlplus -s / as sysdba <<'SQL'
set heading off feedback off pagesize 0 verify off echo off
whenever sqlerror continue
startup
alter database open
alter pluggable database all open
alter pluggable database all save state
whenever sqlerror exit failure
select 'OPEN_MODE=' || open_mode from v\$database where open_mode = 'READ WRITE';
exit success
SQL"
}
stage_run "06-create-database" main
