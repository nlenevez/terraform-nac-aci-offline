#!/usr/bin/env bash
# Build the offline zip from the committed tree:
#   repo (+ .git) + terraform binaries + provider mirror -> dist/*.zip
#   scripts/build-bundle.sh [--allow-dirty]
. "$(dirname "$0")/lib.sh"
cd "$ROOT"

[ "${1:-}" = --allow-dirty ] || [ -z "$(git status --porcelain)" ] || die "uncommitted changes (commit, or pass --allow-dirty to build HEAD anyway)"
command -v zip >/dev/null || die "zip not installed"
TF=$(host_terraform)
SHA=$(git rev-parse --short HEAD)
NAME=nac-aci-airgap-$(date +%F)-$SHA
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
S=$STAGE/nac-aci

log "staging HEAD ($SHA)"
git clone -q --no-hardlinks "$ROOT" "$S"
git -C "$S" remote remove origin

for p in $PLATFORMS; do
  log "terraform $TF_VERSION $p"
  mkdir -p "$S/airgap/bin/$p"
  unzip -oq "$(fetch_terraform "$p")" -d "$S/airgap/bin/$p"
done

log "checking lock file covers: $PLATFORMS"
( cd "$S"
  TF_PLUGIN_CACHE_DIR='' "$TF" init -backend=false -input=false -no-color >/dev/null
  # shellcheck disable=SC2046
  "$TF" providers lock $(platform_flags) -no-color >/dev/null
  git diff --quiet .terraform.lock.hcl || { git diff .terraform.lock.hcl >&2; die "lock file is missing hashes; run scripts/update-providers.sh and commit"; }
  log "mirroring providers"
  # shellcheck disable=SC2046
  "$TF" providers mirror $(platform_flags) airgap/providers -no-color >/dev/null
  rm -rf .terraform
)

mkdir -p dist
rm -f "dist/$NAME.zip"
log "zipping"
(cd "$STAGE" && zip -qr -X "$ROOT/dist/$NAME.zip" nac-aci)
(cd dist && sha256sum "$NAME.zip" > "$NAME.zip.sha256")
ls -l "dist/$NAME.zip" >&2
cat "dist/$NAME.zip.sha256"
