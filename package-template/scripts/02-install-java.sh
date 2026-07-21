#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){ rpm --import https://yum.corretto.aws/corretto.key; curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo; dnf -y install java-11-amazon-corretto-devel; mkdir -p $(json '.profile.java.installationDirectory'); target=$(dirname $(dirname $(readlink -f /usr/bin/java))); ln -sfn "$target" $(json '.profile.java.javaHomeSymlink'); echo "export JAVA_HOME=$(json '.profile.java.javaHomeSymlink')" >/etc/profile.d/windchill-java.sh; java -version; javac -version; }
stage_run "02-install-java" main
