#requires -Version 7.0
param(
  [string]$BuildDirectory = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Push-Location $BuildDirectory
try {
  vagrant provision
  if ($LASTEXITCODE) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}
