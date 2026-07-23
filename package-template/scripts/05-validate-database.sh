#!/usr/bin/env bash
source /vagrant/scripts/common.sh
stage_run "05-validate-database" dispatch_provider validate
