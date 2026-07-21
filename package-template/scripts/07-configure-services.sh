#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  oracle_env
  cat >/usr/local/bin/windchill-listener-start.sh <<EOS
#!/usr/bin/env bash
set -euo pipefail
export ORACLE_HOME="$ORACLE_HOME"
export PATH="\$ORACLE_HOME/bin:\$PATH"
if "\$ORACLE_HOME/bin/lsnrctl" status >/dev/null 2>&1; then
  echo "Oracle listener is already running; leaving it in place."
  exit 0
fi
"\$ORACLE_HOME/bin/lsnrctl" start
EOS
  cat >/usr/local/bin/windchill-listener-stop.sh <<EOS
#!/usr/bin/env bash
set -euo pipefail
export ORACLE_HOME="$ORACLE_HOME"
export PATH="\$ORACLE_HOME/bin:\$PATH"
if "\$ORACLE_HOME/bin/lsnrctl" status >/dev/null 2>&1; then
  "\$ORACLE_HOME/bin/lsnrctl" stop
fi
EOS
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
  chmod 0755 /usr/local/bin/windchill-listener-start.sh /usr/local/bin/windchill-listener-stop.sh /usr/local/bin/windchill-oracle-start.sh /usr/local/bin/windchill-oracle-stop.sh
  chown "$(json '.profile.oracle.user'):$(json '.profile.oracle.inventoryGroup')" /usr/local/bin/windchill-listener-start.sh /usr/local/bin/windchill-listener-stop.sh /usr/local/bin/windchill-oracle-start.sh /usr/local/bin/windchill-oracle-stop.sh
  cat >/etc/systemd/system/oracle-listener.service <<EOS
[Unit]
Description=Oracle Listener
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
User=oracle
Environment=ORACLE_HOME=$ORACLE_HOME
TimeoutStartSec=300
TimeoutStopSec=300
ExecStart=/usr/local/bin/windchill-listener-start.sh
ExecStop=/usr/local/bin/windchill-listener-stop.sh
[Install]
WantedBy=multi-user.target
EOS
  cat >/etc/systemd/system/oracle-database.service <<EOS
[Unit]
Description=Oracle Database
After=oracle-listener.service
[Service]
Type=oneshot
RemainAfterExit=yes
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
