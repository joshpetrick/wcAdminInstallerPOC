#requires -Version 7.0
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
function Read-Json($p){Get-Content -Raw -LiteralPath $p|ConvertFrom-Json -Depth 100}
function Assert-Secrets($s){foreach($n in 'oracleSysPassword','oracleSystemPassword','oraclePdbAdminPassword'){if(-not $s.PSObject.Properties[$n] -or [string]::IsNullOrWhiteSpace($s.$n)){throw "Secret value '$n' must be populated in secrets.json."}}}
$config=Read-Json (Join-Path $PSScriptRoot 'config.json'); $p=$config.profile
$secretsPath=Join-Path $PSScriptRoot 'secrets.json'; if(-not(Test-Path $secretsPath)){Copy-Item (Join-Path $PSScriptRoot 'secrets.example.json') $secretsPath; throw "Created secrets.json. Populate it and rerun: pwsh .\Start-Foundation-Build.ps1"}
Assert-Secrets (Read-Json $secretsPath)
& (Join-Path $PSScriptRoot 'Test-Prerequisites.ps1') -ConfigPath (Join-Path $PSScriptRoot 'config.json')
$work=Join-Path $p.paths.buildDirectory ("$($p.vm.name)-"+(Get-Date -Format yyyyMMddHHmmss)); New-Item -ItemType Directory -Force -Path $work|Out-Null
Copy-Item -Recurse -Force -LiteralPath (Join-Path $PSScriptRoot '*') -Destination $work -Exclude '.vagrant'
$log=Join-Path $work 'build.log'; Push-Location $work
try{ & vagrant up --provider=virtualbox *>&1 | Tee-Object -FilePath $log; if($LASTEXITCODE){throw 'vagrant up failed'}; & vagrant halt; & vagrant package --output "wc-12.1.2-foundation-virtualbox-$($p.artifactVersion).box"; Write-Host 'Build completed; run packaged-box validation before publication.' }
catch{ Write-Error "$($_.Exception.Message). Resume: pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '$work'. Cleanup: pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '$work'"; exit 1 } finally{Pop-Location}
