#!/usr/bin/env bash
set -euo pipefail
STATE=/var/lib/windchill-foundation
STAGES=$STATE/stages
LOGS=$STATE/logs
VALIDATION=$STATE/validation
MANIFEST=$STATE/foundation-manifest.json
mkdir -p "$STAGES" "$LOGS" "$VALIDATION"
CONFIG=/vagrant/config.json
SECRETS=/vagrant/secrets.json
stage_run(){
  local name="$1"; shift
  local marker="$STAGES/$name.done" log="$LOGS/$name.log" start end rc
  if [[ -f "$marker" ]]; then echo "Skipping $name"; return 0; fi
  start=$(date -Is)
  echo "Starting $name (log: $log)" | tee -a "$log"
  set +e
  ( "$@" ) 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  set -e
  end=$(date -Is)
  if [[ $rc -ne 0 ]]; then
    echo "FAILED $name with exit code $rc. Last 80 log lines:" | tee -a "$log"
    tail -n 80 "$log" || true
    return "$rc"
  fi
  jq -n --arg stage "$name" --arg start "$start" --arg finish "$end" '{stage:$stage,startTime:$start,finishTime:$finish,status:"PASS"}' > "$marker"
  echo "Finished $name" | tee -a "$log"
}
json(){ jq -r "$1" "$CONFIG"; }
secret_json(){ jq -r "$1" "$SECRETS"; }
database_provider(){ json '.profile.database.provider'; }
provider_script(){ echo "/vagrant/scripts/database-providers/$(database_provider | tr '[:upper:]' '[:lower:]')/$1.sh"; }
dispatch_provider(){ local action="$1" script; script="$(provider_script "$action")"; [[ -x "$script" ]] || { echo "Database provider $(database_provider) does not implement $action at $script"; return 1; }; "$script"; }
sqlcmd_path(){ if [[ -x /opt/mssql-tools18/bin/sqlcmd ]]; then echo /opt/mssql-tools18/bin/sqlcmd; elif command -v sqlcmd >/dev/null 2>&1; then command -v sqlcmd; else return 1; fi; }
