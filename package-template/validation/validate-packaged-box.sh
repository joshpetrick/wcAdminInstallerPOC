#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/common.sh
/vagrant/scripts/database-providers/sqlserver/validate.sh
systemctl reboot || true
