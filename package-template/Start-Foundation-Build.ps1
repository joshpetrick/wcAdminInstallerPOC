#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json($p) { Get-Content -Raw -LiteralPath $p | ConvertFrom-Json -Depth 100 }
function Assert-Secrets($s) {
  foreach ($n in 'oracleSysPassword','oracleSystemPassword','oraclePdbAdminPassword') {
    if (-not $s.PSObject.Properties[$n] -or [string]::IsNullOrWhiteSpace($s.$n)) { throw "Secret value '$n' must be populated in secrets.json." }
  }
}
function Assert-FileExists([string]$Path,[string]$Purpose) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Purpose was not found at '$Path'. Verify the generated package is complete and rerun Start-Foundation-Build.ps1 from the package directory." }
}
function Copy-PackageToBuildDirectory([string]$SourceDirectory,[string]$DestinationDirectory) {
  New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
  Get-ChildItem -LiteralPath $SourceDirectory -Force |
    Where-Object { $_.Name -notin @('.vagrant') } |
    Copy-Item -Recurse -Force -Destination $DestinationDirectory
  Assert-FileExists (Join-Path $DestinationDirectory 'Vagrantfile') 'The copied build Vagrantfile'
  Assert-FileExists (Join-Path $DestinationDirectory 'config.json') 'The copied build configuration'
}

Assert-FileExists (Join-Path $PSScriptRoot 'Vagrantfile') 'The package Vagrantfile'
Assert-FileExists (Join-Path $PSScriptRoot 'config.json') 'The package configuration'
$config = Read-Json (Join-Path $PSScriptRoot 'config.json')
$p = $config.profile
$secretsPath = Join-Path $PSScriptRoot 'secrets.json'
if (-not (Test-Path -LiteralPath $secretsPath -PathType Leaf)) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'secrets.example.json') -Destination $secretsPath -Force
  throw "Created secrets.json. Populate it and rerun: pwsh .\Start-Foundation-Build.ps1"
}
Assert-Secrets (Read-Json $secretsPath)
& (Join-Path $PSScriptRoot 'Test-Prerequisites.ps1') -ConfigPath (Join-Path $PSScriptRoot 'config.json')
$work = Join-Path $p.paths.buildDirectory ("$($p.vm.name)-" + (Get-Date -Format yyyyMMddHHmmss))
Copy-PackageToBuildDirectory -SourceDirectory $PSScriptRoot -DestinationDirectory $work
$log = Join-Path $work 'build.log'
Push-Location $work
try {
  Assert-FileExists (Join-Path $work 'Vagrantfile') 'The Vagrantfile required by vagrant up'
  & vagrant up --provider=virtualbox *>&1 | Tee-Object -FilePath $log
  if ($LASTEXITCODE) { throw 'vagrant up failed' }
  & vagrant halt
  & vagrant package --output "wc-12.1.2-foundation-virtualbox-$($p.artifactVersion).box"
  Write-Host 'Build completed; run packaged-box validation before publication.'
} catch {
  $message = @(
    $($_.Exception.Message),
    '',
    'Log command:',
    "Get-Content -Path '$log' -Tail 200",
    '',
    'Resume command:',
    "pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '$work'",
    '',
    'Cleanup command:',
    "pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '$work'",
    ''
  ) -join [Environment]::NewLine
  Write-Error $message
  exit 1
} finally {
  Pop-Location
}
