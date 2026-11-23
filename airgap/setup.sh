#!/usr/bin/env bash
# Point terraform at the bundled binary and provider mirror (no internet).
#
#   ./airgap/setup.sh --install   once: puts a `terraform` wrapper in
#                                 ~/.local/bin, so every new shell just works
#   source airgap/setup.sh        this shell only (note: source, not run)
#
# Re-run either after moving or re-extracting the directory.

_nac_dir=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
_nac_root=$(dirname "$_nac_dir")
_nac_rc=$_nac_root/.terraformrc
_nac_tf=$_nac_dir/bin/linux_amd64/terraform

# Config with the absolute mirror path; restore the exec bit in case the zip
# was extracted by something that drops it.
sed "s#@MIRROR@#$_nac_dir/providers#" "$_nac_dir/terraformrc.tmpl" > "$_nac_rc"
chmod +x "$_nac_tf"

if [ "${BASH_SOURCE[0]:-$0}" != "$0" ]; then
  # sourced: set up this shell
  export TF_CLI_CONFIG_FILE=$_nac_rc
  export CHECKPOINT_DISABLE=1
  case ":$PATH:" in *":$_nac_dir/bin/linux_amd64:"*) ;; *) export PATH="$_nac_dir/bin/linux_amd64:$PATH" ;; esac
  hash -r 2>/dev/null
  echo "terraform $("$_nac_tf" version | head -1 | cut -d' ' -f2) ready in this shell (providers: $_nac_dir/providers)"
  unset _nac_dir _nac_root _nac_rc _nac_tf
  return 0
fi

# executed
if [ "${1:-}" != --install ]; then
  cat >&2 <<EOF
Running this script can't change your current shell. Either:

  source airgap/setup.sh            # this shell only
  ./airgap/setup.sh --install       # every shell, via ~/.local/bin/terraform
EOF
  exit 1
fi

mkdir -p "$HOME/.local/bin"
w=$HOME/.local/bin/terraform
cat > "$w" <<EOF
#!/bin/sh
# Installed by $_nac_dir/setup.sh --install
# Bundled terraform + offline provider mirror for $_nac_root
export TF_CLI_CONFIG_FILE="\${TF_CLI_CONFIG_FILE:-$_nac_rc}"
export CHECKPOINT_DISABLE=1
exec "$_nac_tf" "\$@"
EOF
chmod +x "$w"
echo "installed $w -> terraform $("$_nac_tf" version | head -1 | cut -d' ' -f2), providers from $_nac_dir/providers"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "ready: run 'terraform init'" ;;
  *) echo "~/.local/bin isn't on PATH in this shell yet: open a new login shell (RHEL's default ~/.bashrc adds it)" ;;
esac
