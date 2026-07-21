#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  oracle_env
  cat >/usr/local/bin/windchill-oracle-start.sh <<EOS
#!/usr/bin/env bash
set -euo pipefail
export ORACLE_HOME="$ORACLE_HOME"
export ORACLE_SID="$ORACLE_SID"
export PATH="\$ORACLE_HOME/bin:\$PATH"
set +e
status="\$("\$ORACLE_HOME/bin/sqlplus" -s / as sysdba <<'SQL' | tr -d '[:space:]'
set heading off feedback off verify off echo off pagesize 0
select status from v\$instance;
exit
SQL
)"
status_rc=\$?
set -e
if [[ \$status_rc -ne 0 || "\$status" != "OPEN" ]]; then
  echo startup | "\$ORACLE_HOME/bin/sqlplus" / as sysdba
fi
echo "alter pluggable database all open; alter pluggable database all save state;" | "\$ORACLE_HOME/bin/sqlplus" / as sysdba
EOS
  cat >/usr/local/bin/windchill-oracle-stop.sh <<EOS
#!/usr/bin/env bash
set -euo pipefail
export ORACLE_HOME="$ORACLE_HOME"
export ORACLE_SID="$ORACLE_SID"
export PATH="\$ORACLE_HOME/bin:\$PATH"
echo "shutdown immediate" | "\$ORACLE_HOME/bin/sqlplus" / as sysdba
EOS
  chmod 0755 /usr/local/bin/windchill-oracle-start.sh /usr/local/bin/windchill-oracle-stop.sh
  chown "$(json '.profile.oracle.user'):$(json '.profile.oracle.inventoryGroup')" /usr/local/bin/windchill-oracle-start.sh /usr/local/bin/windchill-oracle-stop.sh
  cat >/etc/systemd/system/oracle-listener.service <<EOS
[Unit]
Description=Oracle Listener
After=network.target
[Service]
Type=forking
User=oracle
Environment=ORACLE_HOME=$ORACLE_HOME
TimeoutStartSec=300
TimeoutStopSec=300
ExecStart=$ORACLE_HOME/bin/lsnrctl start
ExecStop=$ORACLE_HOME/bin/lsnrctl stop
[Install]
WantedBy=multi-user.target
EOS
  cat >/etc/systemd/system/oracle-database.service <<EOS
[Unit]
Description=Oracle Database
After=oracle-listener.service
[Service]
Type=forking
User=oracle
Environment=ORACLE_HOME=$ORACLE_HOME ORACLE_SID=$ORACLE_SID
TimeoutStartSec=900
TimeoutStopSec=900
ExecStart=/usr/local/bin/windchill-oracle-start.sh
ExecStop=/usr/local/bin/windchill-oracle-stop.sh
[Install]
WantedBy=multi-user.target
EOS
  systemctl daemon-reload
  systemctl enable --now oracle-listener oracle-database
}
stage_run "07-configure-services" main
