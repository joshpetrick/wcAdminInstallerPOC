#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  oracle_env
  local oracle_user
  oracle_user="$(json '.profile.oracle.user')"
  checks=()
  status=PASS
  add(){ checks+=("{\"name\":\"$1\",\"status\":\"$2\"}"); [[ "$2" == PASS ]] || status=FAIL; }
  hostname | grep -q "$(json '.profile.vm.hostname')" && add hostname PASS || add hostname FAIL
  java -version && javac -version && add java PASS || add java FAIL
  [[ -x "$ORACLE_HOME/bin/sqlplus" ]] && add sqlplus PASS || add sqlplus FAIL
  runuser -u "$oracle_user" -- bash -lc "export ORACLE_BASE='$ORACLE_BASE' ORACLE_HOME='$ORACLE_HOME' ORACLE_SID='$ORACLE_SID' PATH='$ORACLE_HOME/bin':\$PATH; lsnrctl status" && add listener PASS || add listener FAIL
  printf '{"status":"%s","startedAt":"%s","finishedAt":"%s","checks":[%s]}\n' "$status" "$(date -Is)" "$(date -Is)" "$(IFS=,; echo "${checks[*]}")" >$VALIDATION/validation-report.json
  jq -r '.checks[]|"\(.status) \(.name)"' $VALIDATION/validation-report.json >$VALIDATION/validation-report.txt
  [[ "$status" == PASS ]]
}
stage_run "08-validate-foundation" main
