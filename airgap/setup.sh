#!/bin/sh
# Point Terraform at the bundled provider mirror. Source it so the exports
# stick:  . airgap/setup.sh   (bash/zsh: from anywhere; plain sh: from repo root)
src=${BASH_SOURCE:-${ZSH_VERSION:+${(%):-%x}}}
d=$(cd "$(dirname "${src:-$0}")" 2>/dev/null && pwd)
[ -d "$d/providers" ] || d=$(pwd)/airgap
sed "s#@MIRROR@#$d/providers#" "$d/terraformrc.tmpl" > "$d/../.terraformrc"
export TF_CLI_CONFIG_FILE="$(cd "$d/.." && pwd)/.terraformrc"
# restore exec bit in case the zip was extracted by something that drops it
[ -f "$d/bin/linux_amd64/terraform" ] && chmod +x "$d/bin/linux_amd64/terraform" && export PATH="$d/bin/linux_amd64:$PATH"
export CHECKPOINT_DISABLE=1   # no update check (also set in .terraformrc)
echo "TF_CLI_CONFIG_FILE=$TF_CLI_CONFIG_FILE"
echo "terraform: $(command -v terraform)"
# Only lasts for this shell. To make it permanent:
#   echo ". $(cd "$d/.." && pwd)/airgap/setup.sh >/dev/null" >> ~/.bashrc
