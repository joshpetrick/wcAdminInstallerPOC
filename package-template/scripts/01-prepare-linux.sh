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
validate_os(){
  source /etc/os-release
  local expected_major min_minor actual_major actual_minor
  expected_major="$(json '.profile.baseOperatingSystem.majorVersion')"
  min_minor="$(json '.profile.baseOperatingSystem.minimumMinorVersion')"
  [[ "$ID" == "almalinux" ]] || { echo "Expected AlmaLinux for this POC; found $PRETTY_NAME."; return 1; }
  actual_major="${VERSION_ID%%.*}"; actual_minor="${VERSION_ID#*.}"
  [[ "$actual_major" == "$expected_major" ]] || { echo "Expected AlmaLinux major $expected_major; found $VERSION_ID."; return 1; }
  [[ "$actual_minor" -ge "$min_minor" ]] || { echo "Expected AlmaLinux $expected_major.$min_minor or later; found $VERSION_ID."; return 1; }
  jq -n --arg id "$ID" --arg pretty "$PRETTY_NAME" --arg version "$VERSION_ID" '{id:$id,prettyName:$pretty,versionId:$version}' > "$VALIDATION/os-release.json"
}
install_common_packages(){
  dnf -y update
  dnf -y install curl jq tar unzip ca-certificates chrony bind-utils net-tools lsof policycoreutils-python-utils
  systemctl enable --now chronyd
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
  localectl set-locale LANG=en_US.UTF-8 || true
}
main(){ validate_os; configure_headless; install_common_packages; configure_host; }
stage_run "01-prepare-linux" main
