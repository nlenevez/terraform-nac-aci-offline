# Point Terraform at the bundled provider mirror (Windows):
#   . .\airgap\setup.ps1
$d = Split-Path -Parent $MyInvocation.MyCommand.Path
$mirror = (Join-Path $d 'providers') -replace '\\','/'
$rc = Join-Path (Split-Path -Parent $d) 'terraform.rc'
(Get-Content (Join-Path $d 'terraformrc.tmpl')) -replace '@MIRROR@', $mirror | Set-Content -Encoding ascii $rc
$env:TF_CLI_CONFIG_FILE = $rc
$bin = Join-Path $d 'bin\windows_amd64'
if (Test-Path (Join-Path $bin 'terraform.exe')) { $env:PATH = "$bin;$env:PATH" }
"TF_CLI_CONFIG_FILE=$rc"
