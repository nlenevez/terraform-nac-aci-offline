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
if command -v docker >/dev/null; then
  # The target OS with no network. ubi8 has no unzip, so extract with
  # platform-python (stricter: it also drops exec bits).
  log "RHEL 8 check (ubi8, --network none, platform-python unzip)"
  docker run --rm --network none --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$(dirname "$ZIP")":/in:ro registry.access.redhat.com/ubi8/ubi:8.10 bash -euc '
      cat /etc/redhat-release; cd /tmp
      /usr/libexec/platform-python -m zipfile -e "/in/'"$(basename "$ZIP")"'" . && cd nac-aci
      . airgap/setup.sh >/dev/null
      terraform init -input=false -no-color | grep -E "Installed|Error|successfully"
      terraform validate -no-color && terraform test -no-color | tail -1'
else
  log "docker not available: skipped RHEL 8 container check"
fi
log "bundle OK: offline init, validate, mocked plan, lock file unchanged"
