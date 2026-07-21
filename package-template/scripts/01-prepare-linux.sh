#!/usr/bin/env bash
source /vagrant/scripts/common.sh
install_packages(){
  dnf -y update
  if ! dnf -y install oracle-database-preinstall-19c unzip tar curl wget jq net-tools bind-utils chrony lsof policycoreutils-python-utils; then
    echo "oracle-database-preinstall-19c was not available from enabled AlmaLinux repositories; installing explicit Oracle 19c prerequisite packages instead."
    dnf -y install bc binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel libXrender libX11 libXau libXi libXtst libgcc libnsl libstdc++ libstdc++-devel libxcb make net-tools nfs-utils smartmontools sysstat unixODBC unzip tar curl wget jq bind-utils chrony lsof policycoreutils-python-utils
  fi
}
configure_oracle_identity(){
  groupadd -f "$(json '.profile.oracle.inventoryGroup')"
  groupadd -f "$(json '.profile.oracle.dbaGroup')"
  id "$(json '.profile.oracle.user')" >/dev/null 2>&1 || useradd -g "$(json '.profile.oracle.inventoryGroup')" -G "$(json '.profile.oracle.dbaGroup')" "$(json '.profile.oracle.user')"
}
configure_host(){
  hostnamectl set-hostname "$(json '.profile.vm.hostname')"
  grep -q "$(json '.profile.vm.hostname')" /etc/hosts || echo "127.0.1.1 $(json '.profile.vm.hostname')" >> /etc/hosts
  mkdir -p "$(json '.profile.oracle.oracleBase')" "$(json '.profile.oracle.oracleHome')" "$(json '.profile.oracle.inventoryDirectory')" "$(json '.profile.oracle.dataDirectory')" "$(json '.profile.oracle.recoveryDirectory')"
  chown -R "$(json '.profile.oracle.user'):$(json '.profile.oracle.inventoryGroup')" /u01 /u02 /u03
  cat >/etc/sysctl.d/98-windchill-oracle.conf <<'EOF'
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF
  sysctl --system
  cat >/etc/security/limits.d/98-windchill-oracle.conf <<EOF
$(json '.profile.oracle.user') soft nofile 1024
$(json '.profile.oracle.user') hard nofile 65536
$(json '.profile.oracle.user') soft nproc 16384
$(json '.profile.oracle.user') hard nproc 16384
$(json '.profile.oracle.user') soft stack 10240
$(json '.profile.oracle.user') hard stack 32768
EOF
  localectl set-locale LANG=en_US.UTF-8 || true
  systemctl enable --now chronyd
}
main(){ install_packages; configure_oracle_identity; configure_host; }
stage_run "01-prepare-linux" main
