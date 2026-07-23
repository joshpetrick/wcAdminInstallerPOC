#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/common.sh
cfg='.profile.database.sqlServer'
sa_password(){ secret_json '.database.sqlServer.saPassword'; }
validate_password(){
  local p; p="$(sa_password)"
  [[ "$(secret_json '.database.provider')" == SQLSERVER ]]
  [[ -n "$p" && "$p" != "CHANGE_ME" && "$p" != "Password123" ]]
  [[ ${#p} -ge 12 && "$p" =~ [A-Z] && "$p" =~ [a-z] && "$p" =~ [0-9] && "$p" =~ [^A-Za-z0-9] ]] || { echo "SQL Server saPassword must be at least 12 characters and include uppercase, lowercase, numeric, and symbol characters. Avoid dictionary words and the username sa."; return 1; }
}
configure_sql(){
  local sqlcmd pass port max_mem
  sqlcmd="$(sqlcmd_path)"; pass="$(sa_password)"; port="$(json "$cfg.port")"; max_mem="$(json "$cfg.maxMemoryMb")"
  /opt/mssql/bin/mssql-conf set network.tcpport "$port"
  /opt/mssql/bin/mssql-conf set sqlagent.enabled "$(json "$cfg.enableAgent")"
  systemctl restart mssql-server
  "$sqlcmd" -S "localhost,$port" -U sa -P "$pass" -C -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'contained database authentication', 1; RECONFIGURE; EXEC sp_configure 'max server memory (MB)', $max_mem; RECONFIGURE;" >/dev/null
}
main(){
  validate_password
  install -d -m 0700 /run/windchill-foundation
  local envfile=/run/windchill-foundation/mssql-setup.env
  umask 077
  {
    echo "MSSQL_PID='$(json "$cfg.edition")'"
    echo "ACCEPT_EULA='Y'"
    printf "MSSQL_SA_PASSWORD='%s'\n" "$(sa_password | sed "s/'/'\\''/g")"
  } > "$envfile"
  set -a; source "$envfile"; set +a
  /opt/mssql/bin/mssql-conf -n setup >/dev/null
  rm -f "$envfile"
  systemctl enable --now mssql-server
  configure_sql
}
main "$@"
