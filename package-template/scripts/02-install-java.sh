#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  local java_major java_package java_installation_directory java_home_symlink target
  java_major="$(json '.profile.java.majorVersion')"
  java_package="java-${java_major}-amazon-corretto-devel"
  java_installation_directory="$(json '.profile.java.installationDirectory')"
  java_home_symlink="$(json '.profile.java.javaHomeSymlink')"

  echo "Installing Amazon Corretto ${java_major} from profile setting profile.java.majorVersion."
  rpm --import https://yum.corretto.aws/corretto.key
  curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
  dnf -y install "$java_package"
  mkdir -p "$java_installation_directory"
  target="$(dirname "$(dirname "$(readlink -f /usr/bin/java)")")"
  ln -sfn "$target" "$java_home_symlink"
  cat >/etc/profile.d/windchill-java.sh <<EOFJAVA
export JAVA_HOME=$java_home_symlink
export PATH=\$JAVA_HOME/bin:\$PATH
EOFJAVA
  java -version
  javac -version
}
stage_run "02-install-java" main
