# nac-aci

Cisco Network-as-Code for ACI: the APIC config is YAML under `data/`, and
Terraform applies it through the `netascode/nac-aci/aci` module. Packaged to
run on an airgapped machine. No registry or internet access is needed.

| Component | Version | Where |
|---|---|---|
| Terraform CLI | 1.17.2 | `airgap/bin/<platform>/` (zip only) |
| nac-aci module | 2.1.0 | `vendor/nac-aci/` (vendored, in git) |
| CiscoDevNet/aci | 2.21.0 | `airgap/providers/` (zip only) |
| netascode/utils | 2.0.3 | `airgap/providers/` (zip only) |
| hashicorp/local | 2.9.1 | `airgap/providers/` (zip only) |

Platforms bundled: `linux_amd64`, `windows_amd64`. `.terraform.lock.hcl` has
hashes for both. To add another platform, such as `darwin_arm64`, pass an extra
`-platform=` to both commands under "Refreshing" and add that terraform binary.

## Use (airgapped)

```sh
unzip nac-aci-airgap-*.zip && cd nac-aci
. airgap/setup.sh                 # Windows: . .\airgap\setup.ps1
export ACI_URL=https://apic.example ACI_USERNAME=admin ACI_PASSWORD=...
terraform init
terraform plan
```

`setup.sh` writes `.terraformrc` with the absolute path to `airgap/providers`
and points `TF_CLI_CONFIG_FILE` at it. It also puts the bundled terraform on
`PATH`. Run it again after you move the directory.

Edit `data/*.nac.yaml` to describe the fabric. Data model:
<https://netascode.cisco.com/docs/data_models/apic/overview/>.

The `manage_*` flags in `main.tf` control which sections Terraform owns. Only
`manage_tenants` is on. The other sections push fabric-wide defaults (AAA,
password profile, banners, ISIS, MCP, err-disable recovery, QoS) even when the
YAML doesn't mention them, so read the plan before you turn one on against a
live fabric. `data/access_policies.nac.yaml` only takes effect once
`manage_access_policies = true`.

State is local (`terraform.tfstate`, gitignored). Add a `backend` block once
the airgapped side has somewhere to keep it.

## Re-importing into git

The zip contains `.git`. To push it to the airgapped GitLab:

```sh
git remote add origin <url> && git push -u origin main
```

The provider zips and terraform binaries are gitignored, so they don't bloat
the repo. Keep the zip, or copy `airgap/providers` and `airgap/bin` alongside
the repo.

## Refreshing (connected side)

```sh
# module: replace vendor/nac-aci with the new tag's source
curl -sL https://github.com/netascode/terraform-aci-nac-aci/archive/refs/tags/vX.Y.Z.tar.gz | tar xz
terraform init -backend=false -upgrade
terraform providers lock   -platform=linux_amd64 -platform=windows_amd64
terraform providers mirror -platform=linux_amd64 -platform=windows_amd64 airgap/providers
```
