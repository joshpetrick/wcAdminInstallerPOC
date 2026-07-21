#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$BuildDirectory = (Get-Location).Path,
  [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedBuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory)
if (-not (Test-Path -LiteralPath $resolvedBuildDirectory -PathType Container)) {
  throw "Build directory was not found: $resolvedBuildDirectory"
}

if (-not $Force) {
  $answer = Read-Host "Destroy Vagrant VM and remove ${resolvedBuildDirectory}? Type YES"
  if ($answer -ne 'YES') { throw 'Cleanup cancelled' }
}

$vagrantfile = Join-Path $resolvedBuildDirectory 'Vagrantfile'
if (Test-Path -LiteralPath $vagrantfile -PathType Leaf) {
  Push-Location $resolvedBuildDirectory
  try {
    & vagrant destroy -f
    if ($LASTEXITCODE) { throw "vagrant destroy failed with exit code $LASTEXITCODE" }
  } finally {
    Pop-Location
  }
} else {
  Write-Warning "No Vagrantfile was found in '$resolvedBuildDirectory'. Skipping vagrant destroy and removing the directory only."
}

Remove-Item -Recurse -Force -LiteralPath $resolvedBuildDirectory
Write-Host "Removed build directory: $resolvedBuildDirectory"
