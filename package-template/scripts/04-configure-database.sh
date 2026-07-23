#!/usr/bin/env bash
source /vagrant/scripts/common.sh
stage_run "04-configure-database" dispatch_provider configure
