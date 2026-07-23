#requires -Version 7.0
param([Parameter(Mandatory)][string]$ConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-CommandOrPath([string]$CommandName, [string[]]$FallbackPaths) {
  $command = Get-Command $CommandName -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  foreach ($path in $FallbackPaths) {
    if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
  }
  return $null
}

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -Depth 100
if ($config.profile.database.provider -ne 'SQLSERVER') { throw 'Only SQLSERVER is active for this POC; ORACLE is disabled.' }
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 or later is required. Install PowerShell 7, then rerun this command from a PowerShell 7 session.' }

$vagrant = Find-CommandOrPath 'vagrant' @('C:\HashiCorp\Vagrant\bin\vagrant.exe')
if (-not $vagrant) { throw "Vagrant CLI was not found. Install Vagrant, close and reopen PowerShell, then verify with: vagrant --version" }

$virtualBox = Find-CommandOrPath 'VBoxManage' @(
  'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe',
  'C:\Program Files\VirtualBox\VBoxManage.exe'
)
if (-not $virtualBox) {
  throw "VirtualBox was not found. Vagrant can be installed without VirtualBox; install VirtualBox separately. If VirtualBox is installed, add its install directory to PATH or verify the default path exists: C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
}

Write-Host "Prerequisite checks passed for SQLSERVER provider."
Write-Host "Vagrant: $vagrant"
Write-Host "VirtualBox VBoxManage: $virtualBox"
Write-Host 'SQL Server is downloaded inside the VM from Microsoft package repositories; no Oracle or SQL Server installer media is required on the host.'
