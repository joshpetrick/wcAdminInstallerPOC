#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ oracle_env; chmod 600 /vagrant/secrets.json; sys=$(jq -r .oracleSysPassword /vagrant/secrets.json); system=$(jq -r .oracleSystemPassword /vagrant/secrets.json); pdb=$(jq -r .oraclePdbAdminPassword /vagrant/secrets.json); cp /vagrant/oracle/dbca.rsp.template /tmp/dbca.rsp; sed -i "s/__SYS_PASSWORD__/$sys/;s/__SYSTEM_PASSWORD__/$system/;s/__PDB_PASSWORD__/$pdb/" /tmp/dbca.rsp; chown oracle:oinstall /tmp/dbca.rsp; chmod 600 /tmp/dbca.rsp; su - oracle -c "$ORACLE_HOME/bin/dbca -silent -createDatabase -responseFile /tmp/dbca.rsp"; shred -u /tmp/dbca.rsp || rm -f /tmp/dbca.rsp; }
stage_run "06-create-database" main
