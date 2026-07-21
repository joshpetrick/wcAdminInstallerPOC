#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProfilePath,[Parameter(Mandatory)][string]$OutputDirectory)
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
$GeneratorVersion='0.1.0'
function Read-Json([string]$Path){ Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100 }
function Assert-FoundationProfile($p){
  foreach($n in 'profileId','displayName','windchillVersion','compatibilityStatus','provider','artifactVersion','baseOperatingSystem','vm','java','oracle','paths'){ if(-not $p.PSObject.Properties[$n]){ throw "Profile missing required field: $n" } }
  if($p.provider -ne 'virtualbox'){ throw "Invalid provider '$($p.provider)'; only virtualbox is supported." }
  if($p.compatibilityStatus -ne 'POC_NOT_CERTIFIED'){ throw 'Profile must declare POC_NOT_CERTIFIED.' }
  if($p.oracle.edition -notin @('ENTERPRISE','STANDARD_EDITION_2')){ throw 'Invalid Oracle edition.' }
}
function Get-PackageName($p){ "wc-$($p.windchillVersion.Substring(0,6))-foundation-build-$($p.artifactVersion)" }
function Copy-TemplateTree($source,$dest){ New-Item -ItemType Directory -Force -Path $dest|Out-Null; Copy-Item -Recurse -Force -LiteralPath (Join-Path $source '*') -Destination $dest -Exclude 'secrets.json' }
function ConvertTo-StableJson($o){ $o | ConvertTo-Json -Depth 100 }
$repo=Split-Path -Parent $PSCommandPath
$profile=Read-Json (Resolve-Path -LiteralPath $ProfilePath)
Assert-FoundationProfile $profile
$out=New-Item -ItemType Directory -Force -Path $OutputDirectory
$name=Get-PackageName $profile
$pkg=Join-Path $out.FullName $name
$zip=Join-Path $out.FullName "$name.zip"
Remove-Item -Recurse -Force -LiteralPath $pkg,$zip,"$zip.sha256" -ErrorAction SilentlyContinue
Copy-TemplateTree (Join-Path $repo 'package-template') $pkg
$resolved=[ordered]@{ generatorVersion=$GeneratorVersion; generatedAt=(Get-Date).ToUniversalTime().ToString('o'); sourceProfile=(Resolve-Path $ProfilePath).Path; profile=$profile }
(ConvertTo-StableJson $resolved) | Set-Content -Encoding utf8 -LiteralPath (Join-Path $pkg 'config.json')
Remove-Item -Force -LiteralPath (Join-Path $pkg 'config.json.template') -ErrorAction SilentlyContinue
Rename-Item -LiteralPath (Join-Path $pkg 'Vagrantfile.template') -NewName 'Vagrantfile'
Rename-Item -LiteralPath (Join-Path $pkg 'README.md.template') -NewName 'README.md'
Get-ChildItem -Recurse -LiteralPath $pkg -Filter 'secrets.json' | Remove-Item -Force
Get-ChildItem -Recurse -LiteralPath $pkg | Where-Object { $_.Name -eq $profile.oracle.installerFilename -or $_.Extension -eq '.box' } | Remove-Item -Force
Compress-Archive -LiteralPath (Join-Path $pkg '*') -DestinationPath $zip -Force
$hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $zip)" | Set-Content -Encoding ascii -LiteralPath "$zip.sha256"
[ordered]@{packageName=$name;packageDirectory=$pkg;zip=$zip;sha256=$hash;oracleMediaIncluded=$false;secretsIncluded=$false}|ConvertTo-Json|Set-Content -Encoding utf8 -LiteralPath (Join-Path $out.FullName "$name-generation-report.json")
Write-Host "Generated $zip"
