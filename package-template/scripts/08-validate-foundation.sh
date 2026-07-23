#!/usr/bin/env bash
source /vagrant/scripts/common.sh
main(){
  dispatch_provider validate
  cp "$VALIDATION/validation-report.json" /vagrant/validation-report.json
  cp "$VALIDATION/validation-report.txt" /vagrant/validation-report.txt
  cp "$MANIFEST" /vagrant/foundation-manifest.json
}
stage_run "08-validate-foundation" main
