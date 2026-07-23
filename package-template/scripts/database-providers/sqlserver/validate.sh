#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/common.sh
cfg='.profile.database.sqlServer'
version_ge(){ printf '%s
%s
' "$2" "$1" | sort -V -C; }
fail_diag(){
  echo "SQL Server validation failed near: $1"
  systemctl status mssql-server --no-pager || true
  journalctl -u mssql-server -n 80 --no-pager || true
  return 1
}
read_mssql_conf_bool(){
  local key="$1" section="${1%%.*}" name="${1#*.}" value
  value="$(/opt/mssql/bin/mssql-conf get "$key" 2>/dev/null | awk -F= '
    /No setting for the given option/ || /NoSettingForTheGivenOption/ {next}
    NF > 1 {gsub(/[[:space:]]/,"",$2); print tolower($2); next}
    NF == 1 {gsub(/[[:space:]]/,"",$1); print tolower($1)}
  ' | tail -n 1)"
  if [[ -z "$value" && -f /var/opt/mssql/mssql.conf ]]; then
    value="$(awk -v section="[$section]" -v name="$name" '
      tolower($0) == tolower(section) {in_section=1; next}
      /^\[/ {in_section=0}
      in_section {
        split($0, parts, "=")
        key=parts[1]
        gsub(/[[:space:]]/, "", key)
        if (tolower(key) == tolower(name)) {
          value=parts[2]
          gsub(/[[:space:]]/, "", value)
          print tolower(value)
          exit
        }
      }
    ' /var/opt/mssql/mssql.conf)"
  fi
  printf '%s' "$value"
}
is_true_value(){
  [[ "$1" == "true" || "$1" == "1" || "$1" == "yes" || "$1" == "on" ]]
}
main(){
  local sqlcmd port pass metadata version level edition engine package status=PASS contained max_memory agent_enabled agent_xps os_pretty os_version
  sqlcmd="$(sqlcmd_path)"; port="$(json "$cfg.port")"; pass="$(secret_json '.database.sqlServer.saPassword')"
  echo "Validating SQL Server package and executable presence."
  rpm -q mssql-server >/dev/null || fail_diag 'mssql-server package check'
  [[ -x /opt/mssql/bin/sqlservr ]] || fail_diag 'sqlservr executable check'
  "$sqlcmd" -? >/dev/null || fail_diag 'sqlcmd help check'
  echo "Validating SQL Server service and TCP listener."
  systemctl is-enabled mssql-server >/dev/null || fail_diag 'mssql-server enabled check'
  systemctl is-active --quiet mssql-server || fail_diag 'mssql-server active check'
  ss -ltn | grep -q ":$port " || fail_diag "port $port listener check"
  echo "Querying SQL Server product metadata."
  metadata="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -h -1 -W -s '|' -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)), CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)), CAST(SERVERPROPERTY('Edition') AS nvarchar(128)), CAST(SERVERPROPERTY('EngineEdition') AS nvarchar(128));")" || fail_diag 'SERVERPROPERTY metadata query'
  version="$(cut -d'|' -f1 <<<"$metadata")"; level="$(cut -d'|' -f2 <<<"$metadata")"; edition="$(cut -d'|' -f3 <<<"$metadata")"; engine="$(cut -d'|' -f4 <<<"$metadata")"
  [[ "$version" == 16.* ]] || fail_diag "SQL Server major version check: $version"
  version_ge "$version" "$(json "$cfg.minimumProductVersion")" || fail_diag "SQL Server minimum version check: $version"
  [[ "$edition" == *"$(json "$cfg.edition")"* ]] || fail_diag "SQL Server edition check: $edition"
  echo "Validating SQL Server configuration values."
  contained="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -h -1 -W -Q "SET NOCOUNT ON; SELECT value_in_use FROM sys.configurations WHERE name = 'contained database authentication';")" || fail_diag 'contained database authentication query'
  max_memory="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -h -1 -W -Q "SET NOCOUNT ON; SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)';")" || fail_diag 'max server memory query'
  agent_enabled="$(read_mssql_conf_bool sqlagent.enabled)"
  agent_xps="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -h -1 -W -Q "SET NOCOUNT ON; SELECT value_in_use FROM sys.configurations WHERE name = 'Agent XPs';")" || fail_diag 'Agent XPs query'
  [[ "$contained" == "1" ]] || fail_diag "contained database authentication expected 1 found $contained"
  [[ "$max_memory" == "$(json "$cfg.maxMemoryMb")" ]] || fail_diag "max memory expected $(json "$cfg.maxMemoryMb") found $max_memory"
  if [[ "$(json "$cfg.enableAgent")" == "true" ]]; then
    is_true_value "$agent_enabled" || [[ "$agent_xps" == "1" ]] || fail_diag "SQL Server Agent expected true found ${agent_enabled:-<empty>} and Agent XPs $agent_xps; inspect 'sudo /opt/mssql/bin/mssql-conf get sqlagent.enabled' and /var/opt/mssql/mssql.conf"
  fi
  echo "Running temporary database functional validation."
  SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -Q "CREATE DATABASE FoundationValidation; ALTER DATABASE FoundationValidation SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE FoundationValidation;" >/dev/null || fail_diag 'temporary database create/drop'
  ! SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -l 30 -h -1 -Q "SELECT name FROM sys.databases WHERE name='FoundationValidation';" | grep -q FoundationValidation || fail_diag 'temporary database cleanup check'
  package="$(rpm -q mssql-server)"
  os_pretty=$(jq -r '.prettyName' "$VALIDATION/os-release.json")
  os_version=$(jq -r '.versionId' "$VALIDATION/os-release.json")
  jq -n --arg provider SQLSERVER --arg product "Microsoft SQL Server" --arg editionCfg "$(json "$cfg.edition")" --arg platform Linux --argjson port "$port" --arg pkg "$package" --arg version "$version" --arg level "$level" --arg edition "$edition" --arg engine "$engine" --arg osPretty "$os_pretty" --arg osVersion "$os_version" '{database:{provider:$provider,product:$product,edition:$editionCfg,platform:$platform,configuredPort:$port,resolvedPackageVersion:$pkg,resolvedProductVersion:$version,resolvedProductLevel:$level,resolvedEdition:$edition,engineEdition:$engine,validationStatus:"PASSED"},compatibilityStatus:"POC_NOT_CERTIFIED",operatingSystem:{distribution:"AlmaLinux",prettyName:$osPretty,versionId:$osVersion}}' > "$MANIFEST"
  jq -n --arg status "$status" --arg provider SQLSERVER --arg version "$version" --arg edition "$edition" '{status:$status,database:{provider:$provider,resolvedProductVersion:$version,resolvedEdition:$edition},checks:[{name:"mssql-server",status:"PASS"},{name:"sqlcmd",status:"PASS"},{name:"local-sa-connection",status:"PASS"},{name:"temporary-validation-database-cleanup",status:"PASS"}]}' > "$VALIDATION/validation-report.json"
  jq -r '.checks[]|"\(.status) \(.name)"' "$VALIDATION/validation-report.json" > "$VALIDATION/validation-report.txt"
}
main "$@"
