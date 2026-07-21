#requires -Version 7.0
[CmdletBinding()]param([string]$ConfigPath=(Join-Path $PSScriptRoot 'config.json'),[switch]$Quiet)
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
function Read-Json($p){(Get-Content -Raw -LiteralPath $p|ConvertFrom-Json -Depth 100).profile}
function Find-Exe($name,[string[]]$extra){ $cmd=Get-Command $name -ErrorAction SilentlyContinue|Select-Object -First 1; if($cmd){return $cmd.Source}; foreach($p in $extra){if(Test-Path $p){return $p}}; return $null }
function Ver($exe,$arg){ if(-not $exe){return ''}; try{(& $exe $arg 2>&1|Select-Object -First 1) -join ''}catch{''}}
$c=Read-Json $ConfigPath; $oracle=Join-Path $c.paths.oracleMediaDirectory $c.oracle.installerFilename
$checks=@();
$checks += [pscustomobject]@{Name='VBoxManage.exe';Path=(Find-Exe 'VBoxManage.exe' @('C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'));Required=$true}
$checks += [pscustomobject]@{Name='vagrant.exe';Path=(Find-Exe 'vagrant.exe' @('C:\HashiCorp\Vagrant\bin\vagrant.exe'));Required=$true}
$checks += [pscustomobject]@{Name='pwsh.exe';Path=(Find-Exe 'pwsh.exe' @('C:\Program Files\PowerShell\7\pwsh.exe'));Required=$true}
foreach($d in @($c.paths.cacheDirectory,$c.paths.buildDirectory,$c.paths.outputDirectory,$c.paths.mockRepositoryDirectory)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$mediaExists=Test-Path -LiteralPath $oracle; $checksum='MISSING'; if($mediaExists){$checksum=if((Get-FileHash -Algorithm SHA256 -LiteralPath $oracle).Hash.ToLowerInvariant() -eq $c.oracle.installerSha256){'PASS'}else{'FAIL'}}
$result=[pscustomobject]@{executables=$checks|%{[pscustomobject]@{name=$_.Name;path=$_.Path;version=(Ver $_.Path '--version');status=if($_.Path){'PASS'}else{'FAIL'}}};oracleInstaller=[pscustomobject]@{path=$oracle;exists=$mediaExists;checksum=$checksum};host=[pscustomobject]@{memory='detectable on Windows via CIM';diskSpace='checked by directory creation';virtualization='detectable in Task Manager/systeminfo';user=$env:USERNAME}}
if(-not $Quiet){$result|ConvertTo-Json -Depth 5}
if(($checks|?{-not $_.Path}) -or -not $mediaExists -or $checksum -eq 'FAIL'){ throw 'Prerequisite validation failed.' }
