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
wait_for_sqlserver(){
  local sqlcmd port pass deadline
  sqlcmd="$(sqlcmd_path)"; port="$(json "$cfg.port")"; pass="$(sa_password)"; deadline=$((SECONDS + 300))
  echo "Waiting for SQL Server to accept local connections on localhost,$port."
  until SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 5 -Q "SELECT 1" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      echo "SQL Server did not accept local connections within 300 seconds. Recent service status follows."
      systemctl status mssql-server --no-pager || true
      journalctl -u mssql-server -n 120 --no-pager || true
      return 1
    fi
    sleep 5
  done
}
configure_sql(){
  local sqlcmd pass port max_mem current_port
  sqlcmd="$(sqlcmd_path)"; pass="$(sa_password)"; port="$(json "$cfg.port")"; max_mem="$(json "$cfg.maxMemoryMb")"
  echo "Configuring SQL Server TCP port, Agent setting, contained database authentication, and max memory."
  current_port="$(/opt/mssql/bin/mssql-conf get network.tcpport 2>/dev/null | awk -F= '{gsub(/[[:space:]]/,"",$2); print $2}')"
  if [[ "$current_port" == "$port" ]] || { [[ -z "$current_port" ]] && [[ "$port" == "1433" ]] && ss -ltn | grep -q ":$port "; }; then
    echo "SQL Server is already using TCP port $port; skipping mssql-conf network.tcpport set."
  else
    /opt/mssql/bin/mssql-conf set network.tcpport "$port"
  fi
  /opt/mssql/bin/mssql-conf set sqlagent.enabled "$(json "$cfg.enableAgent")"
  timeout 180 systemctl restart mssql-server
  wait_for_sqlserver
  SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'contained database authentication', 1; RECONFIGURE; EXEC sp_configure 'max server memory (MB)', $max_mem; RECONFIGURE;" >/dev/null
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
  echo "Running unattended SQL Server setup."
  timeout 900 /opt/mssql/bin/mssql-conf -n setup >/dev/null
  rm -f "$envfile"
  timeout 180 systemctl enable --now mssql-server
  wait_for_sqlserver
  configure_sql
}
main "$@"
