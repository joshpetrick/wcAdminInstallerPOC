#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ media="/vagrant/$(json '.profile.oracle.installerFilename')"; [[ -f "$media" ]] || media="$(json '.profile.paths.oracleMediaDirectory')/$(json '.profile.oracle.installerFilename')"; mkdir -p /opt/windchill-foundation/oracle-media; cp "$media" /opt/windchill-foundation/oracle-media/; echo "$(json '.profile.oracle.installerSha256')  /opt/windchill-foundation/oracle-media/$(json '.profile.oracle.installerFilename')" | sha256sum -c -; }
stage_run "03-prepare-oracle" main
