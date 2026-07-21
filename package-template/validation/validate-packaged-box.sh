#!/usr/bin/env bash
set -euo pipefail
box=$1; name="wc-foundation-validation-$(date +%s)"; work=$(mktemp -d)
vagrant box add "$name" "$box" --force
trap 'cd /; vagrant box remove "$name" --force || true' EXIT
cd "$work"; printf "Vagrant.configure('2'){|c| c.vm.box='%s'}\n" "$name" > Vagrantfile
vagrant up --provider=virtualbox
vagrant ssh -c 'java -version && sudo systemctl status oracle-listener oracle-database --no-pager'
vagrant reload
vagrant ssh -c 'sudo systemctl is-active oracle-listener oracle-database'
vagrant destroy -f
