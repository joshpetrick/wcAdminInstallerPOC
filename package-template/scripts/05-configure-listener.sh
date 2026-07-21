#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  oracle_env
  local oracle_user
  oracle_user="$(json '.profile.oracle.user')"
  cp /vagrant/oracle/netca.rsp.template /tmp/netca.rsp
  chown "$oracle_user:$(json '.profile.oracle.inventoryGroup')" /tmp/netca.rsp
  runuser -u "$oracle_user" -- bash -lc "export ORACLE_BASE='$ORACLE_BASE' ORACLE_HOME='$ORACLE_HOME' ORACLE_SID='$ORACLE_SID' PATH='$ORACLE_HOME/bin':\$PATH; netca -silent -responseFile /tmp/netca.rsp"
  runuser -u "$oracle_user" -- bash -lc "export ORACLE_BASE='$ORACLE_BASE' ORACLE_HOME='$ORACLE_HOME' ORACLE_SID='$ORACLE_SID' PATH='$ORACLE_HOME/bin':\$PATH; lsnrctl status"
  rm -f /tmp/netca.rsp
}
stage_run "05-configure-listener" main
