#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ dnf -y update; dnf -y install oracle-database-preinstall-19c unzip tar curl wget jq net-tools bind-utils chrony lsof policycoreutils-python-utils; hostnamectl set-hostname "$(json '.profile.vm.hostname')"; grep -q "$(json '.profile.vm.hostname')" /etc/hosts || echo "127.0.1.1 $(json '.profile.vm.hostname')" >> /etc/hosts; mkdir -p $(json '.profile.oracle.oracleBase') $(json '.profile.oracle.oracleHome') $(json '.profile.oracle.inventoryDirectory') $(json '.profile.oracle.dataDirectory') $(json '.profile.oracle.recoveryDirectory'); chown -R oracle:oinstall /u01 /u02 /u03; systemctl enable --now chronyd; }
stage_run "01-prepare-linux" main
