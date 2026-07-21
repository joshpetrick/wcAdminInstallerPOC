#!/usr/bin/env bash
set -euo pipefail
STATE=/var/lib/windchill-foundation; STAGES=$STATE/stages; LOGS=$STATE/logs; VALIDATION=$STATE/validation
mkdir -p "$STAGES" "$LOGS" "$VALIDATION"
CONFIG=/vagrant/config.json
stage_run(){ local name="$1"; shift; local marker="$STAGES/$name.done" log="$LOGS/$name.log" start end; if [[ -f "$marker" ]]; then echo "Skipping $name"; return 0; fi; start=$(date -Is); echo "Starting $name" | tee -a "$log"; ( "$@" ) >>"$log" 2>&1; end=$(date -Is); jq -n --arg stage "$name" --arg start "$start" --arg finish "$end" '{stage:$stage,startTime:$start,finishTime:$finish,status:"PASS"}' > "$marker"; echo "Finished $name" | tee -a "$log"; }
json(){ jq -r "$1" "$CONFIG"; }
oracle_env(){ export ORACLE_BASE=$(json '.profile.oracle.oracleBase'); export ORACLE_HOME=$(json '.profile.oracle.oracleHome'); export PATH=$ORACLE_HOME/bin:$PATH; export ORACLE_SID=$(json '.profile.oracle.sid'); }
