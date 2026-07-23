#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/common.sh
cfg='.profile.database.sqlServer'
validate_config(){
  [[ "$(database_provider)" == SQLSERVER ]]
  [[ "$(json "$cfg.majorVersion")" == 2022 ]]
  [[ "$(json "$cfg.installationSource")" == MICROSOFT_PACKAGE_REPOSITORY ]]
  [[ "$(json "$cfg.repositoryMajorVersion")" == 9 ]]
}
validate_repos(){
  for url in \
    "https://packages.microsoft.com/config/rhel/9/mssql-server-2022.repo" \
    "https://packages.microsoft.com/config/rhel/9/prod.repo"; do
    curl --fail --silent --show-error --location --head --connect-timeout 20 "$url" >/dev/null || {
      echo "Cannot reach Microsoft package endpoint $url. Check DNS, HTTPS inspection/proxy settings, certificates, and repository availability."
      return 1
    }
  done
}
main(){
  validate_config
  validate_repos
  curl --fail --silent --show-error --location https://packages.microsoft.com/config/rhel/9/mssql-server-2022.repo -o /etc/yum.repos.d/mssql-server-2022.repo
  curl --fail --silent --show-error --location https://packages.microsoft.com/config/rhel/9/prod.repo -o /etc/yum.repos.d/msprod.repo
  local policy pinned package_spec
  policy="$(json "$cfg.packageVersionPolicy")"
  pinned="$(json "$cfg.pinnedPackageVersion")"
  if [[ "$policy" == "PINNED" ]]; then
    [[ -n "$pinned" ]] || { echo "SQL Server packageVersionPolicy is PINNED but pinnedPackageVersion is empty."; return 1; }
    package_spec="mssql-server-$pinned"
  else
    package_spec="mssql-server"
  fi
  dnf -y install "$package_spec" unixODBC unixODBC-devel mssql-tools18
  sqlcmd_path >/dev/null
  sqlcmd_path | xargs -I{} {} -? >/dev/null
  rpm -q mssql-server > "$VALIDATION/mssql-server-package-version.txt"
}
main "$@"
