#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  media="/tmp/windchill-foundation-oracle-media/$(json '.profile.oracle.installerFilename')"
  [[ -f "$media" ]] || { echo "Oracle installer was not copied into the guest: $media"; exit 1; }
  mkdir -p /opt/windchill-foundation/oracle-media
  cp "$media" /opt/windchill-foundation/oracle-media/
  echo "$(json '.profile.oracle.installerSha256')  /opt/windchill-foundation/oracle-media/$(json '.profile.oracle.installerFilename')" | sha256sum -c -
}
stage_run "03-prepare-oracle" main
