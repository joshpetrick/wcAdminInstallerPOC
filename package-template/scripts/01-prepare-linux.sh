#!/usr/bin/env bash
source /vagrant/scripts/common.sh
configure_headless(){
  echo "Disabling guest graphical UI and setting non-graphical boot target for this headless development image."
  systemctl set-default multi-user.target
  systemctl isolate multi-user.target || true
  for unit in display-manager.service gdm.service lightdm.service sddm.service; do
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
    systemctl mask "$unit" >/dev/null 2>&1 || true
  done
}
install_packages(){
  dnf -y update
  if ! dnf -y install oracle-database-preinstall-19c unzip tar curl wget jq net-tools bind-utils chrony lsof policycoreutils-python-utils glibc-static libnsl make binutils; then
    echo "oracle-database-preinstall-19c was not available from enabled AlmaLinux repositories; installing explicit Oracle 19c prerequisite packages instead."
    dnf -y install bc binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel glibc-static ksh libaio libaio-devel libXrender libX11 libXau libXi libXtst libgcc libnsl libstdc++ libstdc++-devel libxcb make net-tools nfs-utils smartmontools sysstat unixODBC unzip tar curl wget jq bind-utils chrony lsof policycoreutils-python-utils
  fi
  ensure_build_tools
  ensure_legacy_libnsl
}
ensure_build_tools(){
  dnf -y install make binutils
  if [[ ! -x /usr/bin/make ]]; then
    echo "Oracle relinking requires /usr/bin/make, but make was not installed. Check enabled repositories and rerun this stage."
    return 1
  fi
}
ensure_legacy_libnsl(){
  if [[ -e /usr/lib64/libnsl.so.1 ]] || ldconfig -p 2>/dev/null | grep -q 'libnsl.so.1'; then
    return 0
  fi
  dnf -y install 'libnsl.so.1()(64bit)' || dnf -y install libnsl || true
  if [[ -e /usr/lib64/libnsl.so.1 ]] || ldconfig -p 2>/dev/null | grep -q 'libnsl.so.1'; then
    return 0
  fi
  if [[ -e /usr/lib64/libnsl.so.2 ]]; then
    echo "libnsl.so.1 was not provided by enabled repositories; linking libnsl.so.1 to libnsl.so.2 for the Oracle 19.3 bundled Perl compatibility check in this local POC."
    ln -sfn /usr/lib64/libnsl.so.2 /usr/lib64/libnsl.so.1
    ldconfig
    return 0
  fi
  echo "libnsl.so.1 is required by the Oracle 19.3 bundled Perl but was not found. Enable the repository that provides libnsl.so.1 and rerun this stage."
  return 1
}
configure_oracle_identity(){
  groupadd -f "$(json '.profile.oracle.inventoryGroup')"
  groupadd -f "$(json '.profile.oracle.dbaGroup')"
  id "$(json '.profile.oracle.user')" >/dev/null 2>&1 || useradd -g "$(json '.profile.oracle.inventoryGroup')" -G "$(json '.profile.oracle.dbaGroup')" "$(json '.profile.oracle.user')"
}
configure_host(){
  local vm_hostname primary_ip
  vm_hostname="$(json '.profile.vm.hostname')"
  hostnamectl set-hostname "$vm_hostname"
  primary_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')"
  [[ -n "$primary_ip" ]] || primary_ip="$(hostname -I | awk '{print $1}')"
  [[ -n "$primary_ip" ]] || primary_ip="127.0.0.1"
  sed -i "/[[:space:]]$vm_hostname\b/d" /etc/hosts
  echo "$primary_ip $vm_hostname" >> /etc/hosts
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
main(){ configure_headless; install_packages; configure_oracle_identity; configure_host; }
stage_run "01-prepare-linux" main
