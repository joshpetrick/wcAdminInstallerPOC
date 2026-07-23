#requires -Version 7.0
param(
  [string]$BuildDirectory = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json($p) { Get-Content -Raw -LiteralPath $p | ConvertFrom-Json -Depth 100 }
function ConvertTo-BashSingleQuoted([string]$Value) { return "'" + $Value.Replace("'", "'\\''") + "'" }
function Invoke-RebootValidation([string]$SaPassword,[int]$Port) {
  vagrant ssh -c 'sudo nohup /usr/sbin/shutdown -r now >/dev/null 2>&1 &'
  Start-Sleep -Seconds 15
  $ready = $false
  for ($i = 1; $i -le 60; $i++) {
    vagrant ssh -c 'echo reboot-ready'
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 5
  }
  if (-not $ready) { throw 'VM did not become reachable over SSH after reboot validation restart' }
  $quotedPassword = ConvertTo-BashSingleQuoted $SaPassword
  $validationCommand = "sudo systemctl is-enabled mssql-server >/dev/null && sudo systemctl is-active --quiet mssql-server && sudo ss -ltn | grep -q ':$Port ' && SQLCMDPASSWORD=$quotedPassword /opt/mssql-tools18/bin/sqlcmd -S localhost,$Port -U sa -C -l 30 -Q 'SET NOCOUNT ON; SELECT 1;' >/dev/null"
  vagrant ssh -c $validationCommand
  if ($LASTEXITCODE) { throw 'post-reboot foundation validation failed' }
}

Push-Location $BuildDirectory
try {
  vagrant provision
  if ($LASTEXITCODE) { exit $LASTEXITCODE }
  $config = Read-Json (Join-Path $BuildDirectory 'config.json')
  $secrets = Read-Json (Join-Path $BuildDirectory 'secrets.json')
  Invoke-RebootValidation -SaPassword ([string]$secrets.database.sqlServer.saPassword) -Port ([int]$config.profile.database.sqlServer.port)
} finally {
  Pop-Location
}
