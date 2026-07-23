#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/common.sh
cfg='.profile.database.sqlServer'
version_ge(){ printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
main(){
  local sqlcmd port pass metadata version level edition engine package status=PASS
  sqlcmd="$(sqlcmd_path)"; port="$(json "$cfg.port")"; pass="$(secret_json '.database.sqlServer.saPassword')"
  rpm -q mssql-server >/dev/null
  [[ -x /opt/mssql/bin/sqlservr ]]
  "$sqlcmd" -? >/dev/null
  systemctl is-enabled mssql-server >/dev/null
  systemctl is-active --quiet mssql-server
  ss -ltn | grep -q ":$port "
  metadata="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -h -1 -W -s '|' -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)), CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)), CAST(SERVERPROPERTY('Edition') AS nvarchar(128)), CAST(SERVERPROPERTY('EngineEdition') AS nvarchar(128));")"
  version="$(cut -d'|' -f1 <<<"$metadata")"; level="$(cut -d'|' -f2 <<<"$metadata")"; edition="$(cut -d'|' -f3 <<<"$metadata")"; engine="$(cut -d'|' -f4 <<<"$metadata")"
  [[ "$version" == 16.* ]]
  version_ge "$version" "$(json "$cfg.minimumProductVersion")"
  [[ "$edition" == *"$(json "$cfg.edition")"* ]]
  contained="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -h -1 -W -Q "SET NOCOUNT ON; SELECT value_in_use FROM sys.configurations WHERE name = 'contained database authentication';")"
  max_memory="$(SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -h -1 -W -Q "SET NOCOUNT ON; SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)';")"
  agent_enabled="$(/opt/mssql/bin/mssql-conf get sqlagent.enabled | awk -F= '{gsub(/[[:space:]]/,"",$2); print $2}')"
  [[ "$contained" == "1" ]]
  [[ "$max_memory" == "$(json "$cfg.maxMemoryMb")" ]]
  [[ "$(json "$cfg.enableAgent")" != "true" || "$agent_enabled" == "true" ]]
  SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -Q "CREATE DATABASE FoundationValidation; ALTER DATABASE FoundationValidation SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE FoundationValidation;" >/dev/null
  ! SQLCMDPASSWORD="$pass" "$sqlcmd" -S "localhost,$port" -U sa -C -h -1 -Q "SELECT name FROM sys.databases WHERE name='FoundationValidation';" | grep -q FoundationValidation
  package="$(rpm -q mssql-server)"
  os_pretty=$(jq -r '.prettyName' "$VALIDATION/os-release.json")
  os_version=$(jq -r '.versionId' "$VALIDATION/os-release.json")
  jq -n --arg provider SQLSERVER --arg product "Microsoft SQL Server" --arg editionCfg "$(json "$cfg.edition")" --arg platform Linux --argjson port "$port" --arg pkg "$package" --arg version "$version" --arg level "$level" --arg edition "$edition" --arg engine "$engine" --arg osPretty "$os_pretty" --arg osVersion "$os_version" '{database:{provider:$provider,product:$product,edition:$editionCfg,platform:$platform,configuredPort:$port,resolvedPackageVersion:$pkg,resolvedProductVersion:$version,resolvedProductLevel:$level,resolvedEdition:$edition,engineEdition:$engine,validationStatus:"PASSED"},compatibilityStatus:"POC_NOT_CERTIFIED",operatingSystem:{distribution:"AlmaLinux",prettyName:$osPretty,versionId:$osVersion}}' > "$MANIFEST"
  jq -n --arg status "$status" --arg provider SQLSERVER --arg version "$version" --arg edition "$edition" '{status:$status,database:{provider:$provider,resolvedProductVersion:$version,resolvedEdition:$edition},checks:[{name:"mssql-server",status:"PASS"},{name:"sqlcmd",status:"PASS"},{name:"local-sa-connection",status:"PASS"},{name:"temporary-validation-database-cleanup",status:"PASS"}]}' > "$VALIDATION/validation-report.json"
  jq -r '.checks[]|"\(.status) \(.name)"' "$VALIDATION/validation-report.json" > "$VALIDATION/validation-report.txt"
}
main "$@"
