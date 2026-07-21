#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ oracle_env; cp /vagrant/oracle/netca.rsp.template /tmp/netca.rsp; chown oracle:oinstall /tmp/netca.rsp; su - oracle -c "$ORACLE_HOME/bin/netca -silent -responseFile /tmp/netca.rsp"; su - oracle -c "lsnrctl status"; rm -f /tmp/netca.rsp; }
stage_run "05-configure-listener" main
