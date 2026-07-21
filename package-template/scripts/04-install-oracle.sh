#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  oracle_env
  installer_zip="/opt/windchill-foundation/oracle-media/$(json '.profile.oracle.installerFilename')"
  [[ -f "$installer_zip" ]] || { echo "Oracle installer ZIP is missing in guest staging: $installer_zip"; exit 1; }
  su - oracle -c "unzip -oq '$installer_zip' -d '$ORACLE_HOME'"
  if [[ -f "$ORACLE_HOME/cv/admin/cvu_config" ]]; then
    if grep -q '^#*CV_ASSUME_DISTID=' "$ORACLE_HOME/cv/admin/cvu_config"; then
      sed -i "s/^#*CV_ASSUME_DISTID=.*/CV_ASSUME_DISTID=$CV_ASSUME_DISTID/" "$ORACLE_HOME/cv/admin/cvu_config"
    else
      echo "CV_ASSUME_DISTID=$CV_ASSUME_DISTID" >> "$ORACLE_HOME/cv/admin/cvu_config"
    fi
  fi
  cp /vagrant/oracle/db_install.rsp.template /tmp/db_install.rsp
  chown oracle:oinstall /tmp/db_install.rsp
  echo "Using CV_ASSUME_DISTID=$CV_ASSUME_DISTID for Oracle 19.3 installer OS check compatibility on AlmaLinux."
  set +e
  su - oracle -c "export CV_ASSUME_DISTID='$CV_ASSUME_DISTID'; '$ORACLE_HOME/runInstaller' -silent -responseFile /tmp/db_install.rsp -ignorePrereqFailure -waitforcompletion"
  installer_rc=$?
  set -e
  inventory="$(json '.profile.oracle.inventoryDirectory')"
  if [[ $installer_rc -eq 6 ]]; then
    echo "Oracle installer completed with warnings (exit code 6); continuing because -ignorePrereqFailure is intentional for this AlmaLinux POC."
  elif [[ $installer_rc -ne 0 ]]; then
    echo "Oracle installer failed with exit code $installer_rc. Recent installer logs from $inventory/logs:"
    find "$inventory/logs" -maxdepth 3 -type f -name '*.log' -print -exec tail -n 80 {} \; || true
    exit "$installer_rc"
  fi
  "$inventory/orainstRoot.sh"
  "$ORACLE_HOME/root.sh"
  rm -f /tmp/db_install.rsp
}
stage_run "04-install-oracle" main
