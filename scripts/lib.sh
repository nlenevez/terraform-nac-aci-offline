# shellcheck shell=bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bundle.env
. "$ROOT/bundle.env"
CACHE=${CACHE:-$ROOT/.cache}
HC_FPR=C874011F0AB405110D02105534365D9472D7468F   # HashiCorp release key
log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

host_platform() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case $(uname -m) in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) die "unsupported arch $(uname -m)" ;; esac
  echo "${os}_${arch}"
}

# fetch_terraform PLATFORM -> path of verified zip in $CACHE
fetch_terraform() {
  local plat=$1 d="$CACHE/terraform/$TF_VERSION" base="https://releases.hashicorp.com/terraform/$TF_VERSION"
  local sums="terraform_${TF_VERSION}_SHA256SUMS" zip="terraform_${TF_VERSION}_${plat}.zip"
  mkdir -p "$d"
  if [ ! -f "$d/$sums.verified" ]; then
    curl -fsSL -o "$d/$sums" "$base/$sums"
    curl -fsSL -o "$d/$sums.sig" "$base/$sums.sig"
    local gh; gh=$(mktemp -d); trap 'rm -rf "$gh"' RETURN
    curl -fsSL https://www.hashicorp.com/.well-known/pgp-key.txt | GNUPGHOME=$gh gpg -q --import 2>/dev/null
    GNUPGHOME=$gh gpg -q --list-keys --with-colons | grep -q "^fpr:::::::::$HC_FPR:" || die "HashiCorp key fingerprint mismatch"
    GNUPGHOME=$gh gpg -q --verify "$d/$sums.sig" "$d/$sums" 2>/dev/null || die "bad signature on $sums"
    touch "$d/$sums.verified"
  fi
  [ -f "$d/$zip" ] || curl -fsSL -o "$d/$zip" "$base/$zip"
  (cd "$d" && grep " $zip\$" "$sums" | sha256sum -c --quiet -) || { rm -f "$d/$zip"; die "checksum mismatch for $zip"; }
  echo "$d/$zip"
}

# host_terraform -> path to a terraform binary for this machine
host_terraform() {
  local plat d; plat=$(host_platform); d="$CACHE/bin/$TF_VERSION/$plat"
  if [ ! -x "$d/terraform" ]; then
    mkdir -p "$d"; unzip -oq "$(fetch_terraform "$plat")" terraform -d "$d"
  fi
  echo "$d/terraform"
}

platform_flags() { local p; for p in $PLATFORMS; do printf -- '-platform=%s ' "$p"; done; }
