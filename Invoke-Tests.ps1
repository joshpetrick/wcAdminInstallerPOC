#requires -Version 7.0
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
if(Get-Module -ListAvailable -Name Pester){ Invoke-Pester -Path (Join-Path $PSScriptRoot 'tests') -CI } else { Write-Warning 'Pester is not installed; running built-in static smoke checks.'; & $PSScriptRoot/Generate-Package.ps1 -ProfilePath $PSScriptRoot/profiles/windchill-12.1.2.json -OutputDirectory (Join-Path $env:TMP 'wc poc output'); if($LASTEXITCODE){exit $LASTEXITCODE} }
