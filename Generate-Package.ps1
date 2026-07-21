#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProfilePath,
  [Parameter(Mandatory)][string]$OutputDirectory,
  [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$GeneratorVersion = '0.1.0'
$RepositoryRoot = $PSScriptRoot
$TemplateRoot = Join-Path $RepositoryRoot 'package-template'
$SchemaRoot = Join-Path $RepositoryRoot 'schemas'

function Resolve-ProfilePath([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) { $candidate = $Path }
  else {
    $callerCandidate = Join-Path (Get-Location).Path $Path
    if (Test-Path -LiteralPath $callerCandidate -PathType Leaf) { $candidate = $callerCandidate }
    else { $candidate = Join-Path $RepositoryRoot $Path }
  }
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Package generation failed because the profile was not found.`n`nExpected:`n$candidate`n`nPass a valid -ProfilePath. Relative profile paths are checked from the caller location first, then from the repository root: $RepositoryRoot"
  }
  return (Resolve-Path -LiteralPath $candidate).Path
}

function Resolve-OutputRoot([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) { $candidate = $Path }
  else { $candidate = Join-Path $RepositoryRoot $Path }
  return [System.IO.Path]::GetFullPath($candidate)
}

function Read-Json([string]$Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100 }

function Assert-FoundationProfile($p) {
  foreach ($n in 'profileId','displayName','windchillVersion','compatibilityStatus','provider','artifactVersion','baseOperatingSystem','vm','java','oracle','paths') {
    if (-not $p.PSObject.Properties[$n]) { throw "Profile missing required field: $n" }
  }
  if ($p.provider -ne 'virtualbox') { throw "Invalid provider '$($p.provider)'; only virtualbox is supported." }
  if ($p.compatibilityStatus -ne 'POC_NOT_CERTIFIED') { throw 'Profile must declare POC_NOT_CERTIFIED.' }
  if ($p.oracle.edition -notin @('ENTERPRISE','STANDARD_EDITION_2')) { throw 'Invalid Oracle edition.' }
}

function Get-PackageName($p) { "wc-$($p.windchillVersion.Substring(0,6))-foundation-build-$($p.artifactVersion)" }
function ConvertTo-StableJson($o) { $o | ConvertTo-Json -Depth 100 }

function Assert-TemplateFile([string]$RelativePath) {
  $path = Join-Path $TemplateRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    if ($RelativePath -eq 'Vagrantfile.template') {
      throw "Package generation failed because the required Vagrant template was not found.`n`nOperation:`nValidate package template preflight`n`nExpected:`n$path`n`nVerify that the file exists under package-template and rerun Generate-Package.ps1."
    }
    throw "Package generation failed because a required template file was not found.`n`nOperation:`nValidate package template preflight`n`nExpected:`n$path`n`nVerify that the file exists under package-template and rerun Generate-Package.ps1."
  }
  return $path
}

function Copy-RequiredFile([string]$RelativePath,[string]$DestinationRelativePath = $RelativePath) {
  $source = Assert-TemplateFile $RelativePath
  $destination = Join-Path $PackageDirectory $DestinationRelativePath
  try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
  } catch {
    throw "Package generation failed while copying a required file.`n`nSource:`n$source`n`nDestination:`n$destination`n`nCorrective action: verify the source template exists and the output directory is writable.`n`n$($_.Exception.Message)"
  }
}

function Copy-RequiredDirectory([string]$RelativePath) {
  $source = Join-Path $TemplateRoot $RelativePath
  $destination = Join-Path $PackageDirectory $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Package generation failed because a required template directory was not found.`n`nSource:`n$source`n`nDestination:`n$destination`n`nVerify that the directory exists under package-template and rerun Generate-Package.ps1."
  }
  try {
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Recurse -Force -Destination $destination
  } catch {
    throw "Package generation failed while copying a required directory.`n`nSource:`n$source`n`nDestination:`n$destination`n`nCorrective action: verify the source directory exists and the output directory is writable.`n`n$($_.Exception.Message)"
  }
}

function Assert-GeneratedPackageComplete([string]$PackageDirectory) {
  $required = @(
    'Start-Foundation-Build.ps1','Resume-Foundation-Build.ps1','Clean-Foundation-Build.ps1','Test-Prerequisites.ps1',
    'Vagrantfile','config.json','secrets.example.json','README.md',
    'scripts/common.sh','scripts/01-prepare-linux.sh','scripts/02-install-java.sh','scripts/03-prepare-oracle.sh',
    'scripts/04-install-oracle.sh','scripts/05-configure-listener.sh','scripts/06-create-database.sh','scripts/07-configure-services.sh',
    'scripts/08-validate-foundation.sh','scripts/09-sanitize-foundation.sh',
    'oracle/db_install.rsp.template','oracle/netca.rsp.template','oracle/dbca.rsp.template','validation/validate-packaged-box.sh'
  )
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $PackageDirectory $_) -PathType Leaf) })
  if ($missing.Count -gt 0) {
    throw "Package generation failed because the generated package is incomplete.`n`nPackage directory:`n$PackageDirectory`n`nMissing required paths:`n$($missing -join "`n")`n`nNo ZIP was created. Restore the missing templates and rerun Generate-Package.ps1."
  }
}

foreach ($requiredTemplate in 'Vagrantfile.template','config.json.template','README.md.template','Start-Foundation-Build.ps1','Resume-Foundation-Build.ps1','Clean-Foundation-Build.ps1','Test-Prerequisites.ps1','secrets.example.json') {
  [void](Assert-TemplateFile $requiredTemplate)
}
foreach ($requiredDirectory in 'scripts','oracle','validation') {
  $dir = Join-Path $TemplateRoot $requiredDirectory
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { throw "Package generation failed because required template directory was not found: $dir" }
}

$ProfileAbsolutePath = Resolve-ProfilePath $ProfilePath
$OutputRoot = Resolve-OutputRoot $OutputDirectory
$profile = Read-Json $ProfileAbsolutePath
Assert-FoundationProfile $profile
$name = Get-PackageName $profile
$PackageDirectory = Join-Path $OutputRoot $name
$zip = Join-Path $OutputRoot "$name.zip"
$checksumPath = "$zip.sha256"
$reportPath = Join-Path $OutputRoot "$name-generation-report.json"
$existing = @(@($PackageDirectory,$zip,$checksumPath,$reportPath) | Where-Object { Test-Path -LiteralPath $_ })
if ($existing.Count -gt 0 -and -not $Force) {
  throw "Package generation stopped because output already exists.`n`nExisting path(s):`n$($existing -join "`n")`n`nRerun with -Force to replace only this package directory, ZIP, checksum, and generation report."
}
if ($Force) { foreach ($path in $PackageDirectory,$zip,$checksumPath,$reportPath) { Remove-Item -Recurse -Force -LiteralPath $path -ErrorAction SilentlyContinue } }
New-Item -ItemType Directory -Force -Path $PackageDirectory | Out-Null

foreach ($file in 'Start-Foundation-Build.ps1','Resume-Foundation-Build.ps1','Clean-Foundation-Build.ps1','Test-Prerequisites.ps1','secrets.example.json') { Copy-RequiredFile $file }
foreach ($directory in 'scripts','oracle','validation') { Copy-RequiredDirectory $directory }
Copy-RequiredFile 'Vagrantfile.template' 'Vagrantfile'
Copy-RequiredFile 'README.md.template' 'README.md'
$resolved = [ordered]@{ generatorVersion = $GeneratorVersion; generatedAt = (Get-Date).ToUniversalTime().ToString('o'); sourceProfile = $ProfileAbsolutePath; schemaRoot = $SchemaRoot; profile = $profile }
(ConvertTo-StableJson $resolved) | Set-Content -Encoding utf8 -LiteralPath (Join-Path $PackageDirectory 'config.json')
Get-ChildItem -Recurse -LiteralPath $PackageDirectory -Filter 'secrets.json' | Remove-Item -Force
Get-ChildItem -Recurse -LiteralPath $PackageDirectory | Where-Object { $_.Name -eq $profile.oracle.installerFilename -or $_.Extension -eq '.box' } | Remove-Item -Force
Assert-GeneratedPackageComplete $PackageDirectory
Compress-Archive -Path (Join-Path $PackageDirectory '*') -DestinationPath $zip -Force
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $zip)" | Set-Content -Encoding ascii -LiteralPath $checksumPath
[ordered]@{ packageName = $name; packageDirectory = $PackageDirectory; zip = $zip; sha256 = $hash; oracleMediaIncluded = $false; secretsIncluded = $false } | ConvertTo-Json | Set-Content -Encoding utf8 -LiteralPath $reportPath
Write-Host "Generated $zip"
