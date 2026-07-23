Set-StrictMode -Version Latest
$script:repoRoot = Split-Path -Parent $PSScriptRoot
Describe 'Database provider profile model' {
  It 'accepts SQLSERVER and rejects unsupported providers through generator validation' {
    $profile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'profiles/windchill-13.1.2-sqlserver.json') | ConvertFrom-Json -Depth 100
    $profile.database.provider | Should -Be 'SQLSERVER'
    $profile.database.sqlServer.minimumProductVersion | Should -Be '16.0.4100.1'
    $profile.database.PSObject.Properties['oracle'] | Should -BeNullOrEmpty
  }
  It 'recognizes ORACLE as disabled in the provider documentation' {
    $oracleReadme = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/database-providers/oracle/README.md')
    $oracleReadme | Should -Match 'DISABLED_FOR_CURRENT_POC'
    $oracleReadme | Should -Match 'approved Oracle 19c RU'
  }
}
