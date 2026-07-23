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
function Resolve-ProfilePath([string]$Path) { if ([System.IO.Path]::IsPathRooted($Path)) { $candidate = $Path } else { $callerCandidate = Join-Path (Get-Location).Path $Path; if (Test-Path -LiteralPath $callerCandidate -PathType Leaf) { $candidate = $callerCandidate } else { $candidate = Join-Path $RepositoryRoot $Path } }; if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Profile was not found: $candidate" }; (Resolve-Path -LiteralPath $candidate).Path }
function Resolve-OutputRoot([string]$Path) { if ([System.IO.Path]::IsPathRooted($Path)) { $candidate = $Path } else { $candidate = Join-Path $RepositoryRoot $Path }; [System.IO.Path]::GetFullPath($candidate) }
function Read-Json([string]$Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100 }
function Assert-FoundationProfile($p) {
  foreach ($n in 'profileId','displayName','windchillVersion','compatibilityStatus','provider','artifactVersion','baseOperatingSystem','vm','java','database','paths') { if (-not $p.PSObject.Properties[$n]) { throw "Profile missing required field: $n" } }
  if ($p.provider -ne 'virtualbox') { throw "Invalid provider '$($p.provider)'; only virtualbox is supported." }
  if ($p.compatibilityStatus -ne 'POC_NOT_CERTIFIED') { throw 'Profile must declare POC_NOT_CERTIFIED.' }
  if ($p.database.provider -notin @('SQLSERVER','ORACLE')) { throw "Unsupported database provider '$($p.database.provider)'." }
  if ($p.database.provider -eq 'SQLSERVER') {
    if (-not $p.database.PSObject.Properties['sqlServer']) { throw 'database.sqlServer is required when database.provider is SQLSERVER.' }
    $s = $p.database.sqlServer
    foreach ($n in 'majorVersion','edition','installationSource','repositoryPlatform','repositoryMajorVersion','packageVersionPolicy','minimumProductVersion','port','enableAgent','enableContainedDatabaseAuthentication','createWindchillDatabase','maxMemoryMb','dataDirectory','logDirectory','backupDirectory') { if (-not $s.PSObject.Properties[$n]) { throw "database.sqlServer missing required field: $n" } }
    if ($s.majorVersion -ne '2022') { throw 'The active SQLSERVER POC requires SQL Server 2022.' }
    if ($s.edition -ne 'Developer') { throw 'The active SQLSERVER POC requires Developer edition unless a future profile extends validation.' }
    if ($s.packageVersionPolicy -notin @('LATEST_AVAILABLE','PINNED')) { throw 'Invalid SQL Server packageVersionPolicy.' }
    if ($s.packageVersionPolicy -eq 'PINNED' -and [string]::IsNullOrWhiteSpace($s.pinnedPackageVersion)) { throw 'Pinned SQL Server package version is required when packageVersionPolicy is PINNED.' }
    if ([version]$s.minimumProductVersion -lt [version]'16.0.4100.1') { throw 'SQL Server 2022 on RHEL 9 requires CU10 or later: minimumProductVersion must be at least 16.0.4100.1.' }
  }
  if ($p.database.provider -eq 'ORACLE') { throw 'ORACLE provider is recognized but DISABLED_FOR_CURRENT_POC. Use SQLSERVER for the active POC.' }
}
function Get-VersionLabel($p) { ($p.windchillVersion -replace '\.0$','') }
function Get-PackageName($p) { "wc-$(Get-VersionLabel $p)-foundation-build-$($p.database.provider.ToLowerInvariant())-$($p.artifactVersion)" }
function Convert-TextFileToLf([string]$Path) { $content = [System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n" -replace "`r", "`n"; [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false)) }
function Convert-GeneratedShellScriptsToLf([string]$PackageDirectory) { Get-ChildItem -LiteralPath $PackageDirectory -Recurse -File -Include '*.sh' | ForEach-Object { Convert-TextFileToLf $_.FullName } }
function Copy-RequiredFile([string]$RelativePath,[string]$DestinationRelativePath = $RelativePath) { $source = Join-Path $TemplateRoot $RelativePath; if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required template file missing: $source" }; $destination = Join-Path $PackageDirectory $DestinationRelativePath; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null; Copy-Item -LiteralPath $source -Destination $destination -Force }
function Copy-RequiredDirectory([string]$RelativePath) { $source = Join-Path $TemplateRoot $RelativePath; $destination = Join-Path $PackageDirectory $RelativePath; if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Required template directory missing: $source" }; New-Item -ItemType Directory -Force -Path $destination | Out-Null; Get-ChildItem -LiteralPath $source -Force | Copy-Item -Recurse -Force -Destination $destination }
function Assert-GeneratedPackageComplete([string]$PackageDirectory,$p) {
  $required = @('Start-Foundation-Build.ps1','Resume-Foundation-Build.ps1','Clean-Foundation-Build.ps1','Test-Prerequisites.ps1','Vagrantfile','config.json','secrets.example.json','README.md','scripts/common.sh','scripts/01-prepare-linux.sh','scripts/02-install-java.sh','scripts/03-install-database.sh','scripts/04-configure-database.sh','scripts/05-validate-database.sh','scripts/06-reboot-validation.sh','scripts/07-sanitize-foundation.sh','scripts/08-validate-foundation.sh','scripts/database-providers/sqlserver/install.sh','scripts/database-providers/sqlserver/configure.sh','scripts/database-providers/sqlserver/validate.sh','scripts/database-providers/sqlserver/sanitize.sh','validation/validate-packaged-box.sh')
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $PackageDirectory $_) -PathType Leaf) })
  if ($missing.Count -gt 0) { throw "Generated package is incomplete. Missing: $($missing -join ', ')" }
  if (Test-Path -LiteralPath (Join-Path $PackageDirectory 'scripts/database-providers/oracle/response-templates')) { throw 'SQLSERVER package must not include Oracle response templates.' }
}
$ProfileAbsolutePath = Resolve-ProfilePath $ProfilePath
$OutputRoot = Resolve-OutputRoot $OutputDirectory
$profile = Read-Json $ProfileAbsolutePath
Assert-FoundationProfile $profile
$name = Get-PackageName $profile
$PackageDirectory = Join-Path $OutputRoot $name; $zip = Join-Path $OutputRoot "$name.zip"; $checksumPath = "$zip.sha256"; $reportPath = Join-Path $OutputRoot "$name-generation-report.json"
$existing = @(@($PackageDirectory,$zip,$checksumPath,$reportPath) | Where-Object { Test-Path -LiteralPath $_ })
if ($existing.Count -gt 0 -and -not $Force) { throw "Output already exists: $($existing -join ', ')" }
if ($Force) { foreach ($path in $PackageDirectory,$zip,$checksumPath,$reportPath) { Remove-Item -Recurse -Force -LiteralPath $path -ErrorAction SilentlyContinue } }
New-Item -ItemType Directory -Force -Path $PackageDirectory | Out-Null
foreach ($file in 'Start-Foundation-Build.ps1','Resume-Foundation-Build.ps1','Clean-Foundation-Build.ps1','Test-Prerequisites.ps1','secrets.example.json') { Copy-RequiredFile $file }
Copy-RequiredDirectory 'scripts'
if ($profile.database.provider -eq 'SQLSERVER') { Remove-Item -Recurse -Force -LiteralPath (Join-Path $PackageDirectory 'scripts/database-providers/oracle') -ErrorAction SilentlyContinue }
Copy-RequiredDirectory 'validation'
Copy-RequiredFile 'Vagrantfile.template' 'Vagrantfile'; Copy-RequiredFile 'README.md.template' 'README.md'
[ordered]@{ generatorVersion = $GeneratorVersion; generatedAt = (Get-Date).ToUniversalTime().ToString('o'); sourceProfile = $ProfileAbsolutePath; schemaRoot = $SchemaRoot; profile = $profile } | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $PackageDirectory 'config.json')
Get-ChildItem -Recurse -LiteralPath $PackageDirectory -Filter 'secrets.json' | Remove-Item -Force
Convert-GeneratedShellScriptsToLf $PackageDirectory
Assert-GeneratedPackageComplete $PackageDirectory $profile
Compress-Archive -Path (Join-Path $PackageDirectory '*') -DestinationPath $zip -Force
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant(); "$hash  $(Split-Path -Leaf $zip)" | Set-Content -Encoding ascii -LiteralPath $checksumPath
[ordered]@{ packageName = $name; packageDirectory = $PackageDirectory; zip = $zip; sha256 = $hash; databaseProvider = $profile.database.provider; secretsIncluded = $false } | ConvertTo-Json | Set-Content -Encoding utf8 -LiteralPath $reportPath
Write-Host "Generated $zip"
