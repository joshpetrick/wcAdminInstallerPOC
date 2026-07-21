#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ oracle_env; su - oracle -c "unzip -oq /opt/windchill-foundation/oracle-media/$(json '.profile.oracle.installerFilename') -d $ORACLE_HOME"; cp /vagrant/oracle/db_install.rsp.template /tmp/db_install.rsp; chown oracle:oinstall /tmp/db_install.rsp; su - oracle -c "$ORACLE_HOME/runInstaller -silent -responseFile /tmp/db_install.rsp -ignorePrereqFailure -waitforcompletion" || { cat $ORACLE_BASE/oraInventory/logs/installActions*.log; exit 1; }; /u01/app/oraInventory/orainstRoot.sh; $ORACLE_HOME/root.sh; rm -f /tmp/db_install.rsp; }
stage_run "04-install-oracle" main
