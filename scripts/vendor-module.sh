#!/usr/bin/env bash
# Replace vendor/nac-aci with a release of netascode/terraform-aci-nac-aci.
#   scripts/vendor-module.sh [VERSION]    (default: latest on the registry)
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
V=${1:-$(curl -fsSL https://registry.terraform.io/v1/modules/netascode/nac-aci/aci | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])')}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
log "fetching nac-aci v$V"
curl -fsSL "https://github.com/netascode/terraform-aci-nac-aci/archive/refs/tags/v$V.tar.gz" | tar xz -C "$T"
rm -rf vendor/nac-aci
mv "$T/terraform-aci-nac-aci-$V" vendor/nac-aci
rm -rf vendor/nac-aci/.github
sed -i "s/^MODULE_VERSION=.*/MODULE_VERSION=$V/" bundle.env
sed -i "s#netascode/nac-aci/aci v[0-9.]*#netascode/nac-aci/aci v$V#" main.tf
log "vendored v$V; now run scripts/update-providers.sh, review, commit"
diff <(sed -n '/required_providers/,/^  }/p' vendor/nac-aci/versions.tf) <(sed -n '/required_providers/,/^  }/p' versions.tf) >/dev/null \
  || log "WARNING: module provider constraints differ from versions.tf — update versions.tf to match"
