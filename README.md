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

Target: **RHEL 8 x86_64** (`linux_amd64`). Terraform and all three providers
are statically linked Go binaries, so there's no glibc or package dependency.
Versions and platforms are set in `bundle.env`; see "Building the bundle".

## Use (airgapped, RHEL 8)

```sh
sha256sum -c nac-aci-airgap-*.zip.sha256
unzip -q nac-aci-airgap-*.zip && cd nac-aci
. airgap/setup.sh
export ACI_URL=https://apic.example ACI_USERNAME=admin ACI_PASSWORD=...
terraform init
terraform plan
```

Minimal RHEL 8 installs have no `unzip`. Either install it from the BaseOS
media (`dnf install unzip`), or use the Python that RHEL 8 always ships:
`/usr/libexec/platform-python -m zipfile -e nac-aci-airgap-*.zip .`
(`setup.sh` restores the terraform exec bit that this drops). `git` is only
needed to push the repo on; it's in the AppStream media.

On STIG-hardened hosts, keep the directory off `noexec` mounts (often `/tmp`,
sometimes `/home`). Terraform runs the provider binaries from `.terraform/`
inside the repo.

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

## Building the bundle (connected side)

Needs `bash`, `curl`, `gpg`, `unzip`, `zip`, `git` and internet access.
Terraform is downloaded into `.cache/` automatically, checked against
HashiCorp's GPG-signed SHA256SUMS.

```sh
scripts/build-bundle.sh                    # -> dist/nac-aci-airgap-<date>-<sha>.zip + .sha256
scripts/verify-bundle.sh dist/nac-aci-airgap-*.zip   # offline init/validate/test
```

The build clones the **committed** HEAD into a staging dir, so the zip's
`.git` is exactly what's in git. It refuses to run with uncommitted changes
unless you pass `--allow-dirty`. Versions are set in `bundle.env`. The build
fails if `.terraform.lock.hcl` is missing hashes for a platform in
`PLATFORMS`.

| Task | Command |
|---|---|
| New nac-aci release | `scripts/vendor-module.sh [X.Y.Z]` then `scripts/update-providers.sh` |
| Newer providers | `scripts/update-providers.sh` |
| Newer terraform | edit `TF_VERSION` in `bundle.env` |
| Another platform | add it to `PLATFORMS` in `bundle.env`, then `scripts/update-providers.sh` |

Commit after each of these, then rebuild.

## Checking the YAML without an APIC

`terraform test` plans against a mocked ACI provider
(`tests/plan.tftest.hcl`). This works on the airgapped side too.
