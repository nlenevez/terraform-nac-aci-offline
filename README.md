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
./airgap/setup.sh --install       # once: `terraform` now works in every shell
export ACI_URL=https://apic.example ACI_USERNAME=admin ACI_PASSWORD=...
terraform init
terraform plan
```

Needs only `unzip` and `git` (`dnf install unzip git`, from BaseOS/AppStream
via Satellite). Nothing comes from EPEL or HashiCorp's repo; terraform and
the providers ship in the zip.

On STIG-hardened hosts, keep the directory off `noexec` mounts (often `/tmp`,
sometimes `/home`). Terraform runs the provider binaries from `.terraform/`
inside the repo.

`--install` writes `.terraformrc` (absolute path to `airgap/providers`) and a
small `~/.local/bin/terraform` wrapper. The wrapper runs the bundled binary with
that config and with update checks off. `~/.local/bin` is first on `PATH` on
RHEL 8 by default. Re-run it after moving or re-extracting the directory. It
replaces any other `terraform` you run as that user, and points it at this
mirror.

To set up just the current shell instead, use `source airgap/setup.sh`.
Running it without `source` can't change your shell, so the script then prints
these two options instead of silently doing nothing.

### Troubleshooting `terraform init`

- **Hundreds of lines like `- aci.aci_xxx in vendor/nac-aci/modules/...`** on
  the first init. These are local: terraform links the module's ~240
  submodules from `vendor/`. Nothing is downloaded. Later inits skip them.
- **`terraform: command not found`, or
  `Failed to query available provider packages ... registry.terraform.io`.**
  This shell isn't using the bundle. Without it, terraform goes to the
  internet registry instead of `airgap/providers`. Run
  `./airgap/setup.sh --install` once, then open a new shell.
- **Update checks.** The bundle turns off terraform's call to
  `checkpoint-api.hashicorp.com` (`disable_checkpoint` and
  `CHECKPOINT_DISABLE=1`).
- **Check what's in effect:** `which terraform` should be
  `~/.local/bin/terraform` (or `airgap/bin/...` if sourced), and
  `terraform version` should be 1.17.2.

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

### On GitHub

`.github/workflows/release.yml` does the same on GitHub Actions. Push a tag
(`git tag v2.1.0-1 && git push github v2.1.0-1`) and it builds, verifies
(offline namespace + RHEL 8 container) and attaches the zip and `.sha256` to
a Release. A manual run (`workflow_dispatch`) keeps the zip as a workflow
artifact instead. Tag scheme: `v<module version>-<n>`.

## Checking the YAML without an APIC

`terraform test` plans against a mocked ACI provider
(`tests/plan.tftest.hcl`). This works on the airgapped side too.
