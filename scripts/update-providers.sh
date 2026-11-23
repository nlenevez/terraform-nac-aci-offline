#!/usr/bin/env bash
# Upgrade providers to the newest versions versions.tf allows (and, with
# vendor/nac-aci, the module's constraints) and rewrite .terraform.lock.hcl
# with hashes for every platform in bundle.env. Commit the result.
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
TF=$(host_terraform)
TF_PLUGIN_CACHE_DIR='' "$TF" init -backend=false -upgrade -input=false -no-color | grep -E 'Installed|Error' || true
# shellcheck disable=SC2046
"$TF" providers lock $(platform_flags) -no-color >/dev/null
rm -rf .terraform
grep -E '^provider|version ' .terraform.lock.hcl
git diff --stat .terraform.lock.hcl
