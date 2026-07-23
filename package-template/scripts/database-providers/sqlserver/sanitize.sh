#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/common.sh
main(){
  rm -f /run/windchill-foundation/mssql-setup.env /tmp/*mssql* /tmp/*sqlcmd* || true
  rm -f /root/.bash_history /home/vagrant/.bash_history || true
  dnf clean all
  rm -rf /var/cache/dnf /var/tmp/*
  rm -f /etc/machine-id; touch /etc/machine-id
  dispatch_provider validate
  echo '{"removed":["temporary SQL setup environment files","temporary SQL scripts","shell histories","package-manager caches","machine-id"],"preserved":["SQL Server binaries","configured SQL Server instance","system databases","sqlcmd tools","SQL Server Agent configuration","contained database authentication","memory configuration","port configuration","Vagrant SSH access"]}' > "$STATE/sanitization-report.json"
}
main "$@"
