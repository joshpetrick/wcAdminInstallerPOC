#!/usr/bin/env bash
set -euo pipefail
STATE=/var/lib/windchill-foundation
STAGES=$STATE/stages
LOGS=$STATE/logs
VALIDATION=$STATE/validation
mkdir -p "$STAGES" "$LOGS" "$VALIDATION"
CONFIG=/vagrant/config.json
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
oracle_env(){ export ORACLE_BASE=$(json '.profile.oracle.oracleBase'); export ORACLE_HOME=$(json '.profile.oracle.oracleHome'); export PATH=$ORACLE_HOME/bin:$PATH; export ORACLE_SID=$(json '.profile.oracle.sid'); export CV_ASSUME_DISTID=$(json '.profile.oracle.assumedDistribution // "OEL7.8"'); }
