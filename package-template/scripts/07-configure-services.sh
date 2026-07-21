#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ oracle_env; cat >/etc/systemd/system/oracle-listener.service <<EOF
[Unit]
Description=Oracle Listener
After=network.target
[Service]
Type=forking
User=oracle
Environment=ORACLE_HOME=$ORACLE_HOME
ExecStart=$ORACLE_HOME/bin/lsnrctl start
ExecStop=$ORACLE_HOME/bin/lsnrctl stop
[Install]
WantedBy=multi-user.target
EOF
cat >/etc/systemd/system/oracle-database.service <<EOF
[Unit]
Description=Oracle Database
After=oracle-listener.service
[Service]
Type=forking
User=oracle
Environment=ORACLE_HOME=$ORACLE_HOME ORACLE_SID=$ORACLE_SID
ExecStart=/bin/bash -lc 'echo startup | $ORACLE_HOME/bin/sqlplus / as sysdba && echo "alter pluggable database all open; alter pluggable database all save state;" | $ORACLE_HOME/bin/sqlplus / as sysdba'
ExecStop=/bin/bash -lc 'echo "shutdown immediate" | $ORACLE_HOME/bin/sqlplus / as sysdba'
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable --now oracle-listener oracle-database; }
stage_run "07-configure-services" main
