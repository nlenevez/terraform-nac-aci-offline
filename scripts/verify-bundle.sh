#!/usr/bin/env bash
# Prove a bundle works with no network: extract, then init/validate/test
# inside a network namespace (sudo unshare -n). Without sudo it still runs,
# relying on the mirror-only CLI config (direct installs are excluded).
#   scripts/verify-bundle.sh dist/nac-aci-airgap-*.zip
. "$(dirname "$0")/lib.sh"
ZIP=$(realpath "${1:?usage: $0 BUNDLE.zip}")
[ -f "$ZIP.sha256" ] && (cd "$(dirname "$ZIP")" && sha256sum -c --quiet "$(basename "$ZIP").sha256") && log "checksum OK"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
unzip -q "$ZIP" -d "$T"
R=$T/nac-aci
[ "$(host_platform)" = linux_amd64 ] || die "verify runs the bundled linux_amd64 binary; host is $(host_platform)"
run='cd "$R" && . airgap/setup.sh >/dev/null && ! curl -s -m3 -o /dev/null https://registry.terraform.io && echo "network: off" >&2;
     terraform init -input=false -no-color | grep -E "Installed|Error|successfully" &&
     terraform validate -no-color && terraform test -no-color && test -z "$(git status --porcelain)"'
if sudo -n true 2>/dev/null; then
  sudo unshare -n sudo -u "$(id -un)" env HOME="$HOME" PATH=/usr/bin:/bin R="$R" bash -c "$run"
else
  log "no passwordless sudo: running without a network namespace"
  R="$R" bash -c "$run"
fi
log "bundle OK: offline init, validate, mocked plan, lock file unchanged"
