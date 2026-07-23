#requires -Version 7.0
param([Parameter(Mandatory)][string]$ConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -Depth 100
if ($config.profile.database.provider -ne 'SQLSERVER') { throw 'Only SQLSERVER is active for this POC; ORACLE is disabled.' }
foreach ($cmd in 'vagrant','VBoxManage') {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Required command '$cmd' was not found. Install Vagrant and VirtualBox before running the Admin foundation build." }
}
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 or later is required.' }
Write-Host 'Prerequisite checks passed for SQLSERVER provider. SQL Server is downloaded inside the VM from Microsoft package repositories; no Oracle or SQL Server installer media is required on the host.'
