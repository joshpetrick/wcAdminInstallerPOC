#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Read-Json($p) { Get-Content -Raw -LiteralPath $p | ConvertFrom-Json -Depth 100 }
function Assert-FileExists([string]$Path,[string]$Purpose) { if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Purpose was not found at '$Path'." } }
function Assert-Secrets($s) {
  if ($s.database.provider -ne 'SQLSERVER') { throw 'secrets.json must declare database.provider SQLSERVER.' }
  $p = [string]$s.database.sqlServer.saPassword
  if ([string]::IsNullOrWhiteSpace($p) -or $p -in @('CHANGE_ME','Password123','')) { throw "Secret value 'database.sqlServer.saPassword' must be populated in secrets.json." }
  if ($p.Length -lt 8 -or $p -notmatch '[A-Z]' -or $p -notmatch '[a-z]' -or $p -notmatch '[0-9]' -or $p -notmatch '[^A-Za-z0-9]') { throw 'SQL Server SA password must satisfy complexity requirements.' }
}
function Copy-PackageToBuildDirectory([string]$SourceDirectory,[string]$DestinationDirectory) {
  New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
  Get-ChildItem -LiteralPath $SourceDirectory -Force | Where-Object { $_.Name -notin @('.vagrant') } | Copy-Item -Recurse -Force -Destination $DestinationDirectory
}
Assert-FileExists (Join-Path $PSScriptRoot 'Vagrantfile') 'The package Vagrantfile'
Assert-FileExists (Join-Path $PSScriptRoot 'config.json') 'The package configuration'
$config = Read-Json (Join-Path $PSScriptRoot 'config.json')
$p = $config.profile
$secretsPath = Join-Path $PSScriptRoot 'secrets.json'
if (-not (Test-Path -LiteralPath $secretsPath -PathType Leaf)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'secrets.example.json') -Destination $secretsPath -Force; throw "Created secrets.json. Populate database.sqlServer.saPassword and rerun: pwsh .\Start-Foundation-Build.ps1" }
Assert-Secrets (Read-Json $secretsPath)
& (Join-Path $PSScriptRoot 'Test-Prerequisites.ps1') -ConfigPath (Join-Path $PSScriptRoot 'config.json')
$work = Join-Path $p.paths.buildDirectory ("$($p.vm.name)-" + (Get-Date -Format yyyyMMddHHmmss))
Copy-PackageToBuildDirectory -SourceDirectory $PSScriptRoot -DestinationDirectory $work
$log = Join-Path $work 'build.log'
Push-Location $work
try {
  & vagrant up --provider=virtualbox *>&1 | Tee-Object -FilePath $log
  if ($LASTEXITCODE) { throw 'vagrant up failed' }
  & vagrant halt
  $versionLabel = $p.windchillVersion.Substring(0,6)
  $boxName = "wc-$versionLabel-foundation-alma9-sqlserver2022-virtualbox-$($p.artifactVersion).box"
  & vagrant package --output $boxName
  $publishRoot = Join-Path $p.paths.mockRepositoryDirectory "Foundations\wc-$versionLabel\$($p.artifactVersion)\virtualbox\sqlserver"
  New-Item -ItemType Directory -Force -Path $publishRoot | Out-Null
  Copy-Item -Force $boxName,(Join-Path $work 'foundation-manifest.json'),(Join-Path $work 'validation-report.json'),(Join-Path $work 'validation-report.txt'),$log -Destination $publishRoot
  (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $publishRoot $boxName)).Hash.ToLowerInvariant() | Set-Content -Encoding ascii -LiteralPath (Join-Path $publishRoot "$boxName.sha256")
  Write-Host "Build completed and published to $publishRoot"
} catch { Write-Error ((@($_.Exception.Message,'','Log command:',"Get-Content -Path '$log' -Tail 200",'','Resume command:',"pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '$work'",'','Cleanup command:',"pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '$work'",'')) -join [Environment]::NewLine); exit 1 } finally { Pop-Location }
