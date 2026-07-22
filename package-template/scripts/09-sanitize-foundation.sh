#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ rm -rf /opt/windchill-foundation/oracle-media /tmp/db*.rsp /tmp/netca.rsp /home/oracle/.bash_history /root/.bash_history; dnf clean all; rm -f /etc/machine-id; touch /etc/machine-id; echo '{"removed":["oracle installer zip","temporary response files","shell histories","dnf caches","machine-id"],"preserved":["vagrant user","vagrant ssh","Oracle software","clean database","validation metadata"]}' >$STATE/sanitization-report.json; }
stage_run "09-sanitize-foundation" main
