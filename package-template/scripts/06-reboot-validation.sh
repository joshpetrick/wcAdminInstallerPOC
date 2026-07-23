#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  systemctl is-enabled mssql-server
  systemctl is-active --quiet mssql-server
  ss -ltn | grep -q ':1433 '
  /vagrant/scripts/database-providers/sqlserver/validate.sh --reboot-check
}
stage_run "06-reboot-validation" main
