Set-StrictMode -Version Latest
$script:repoRoot = Split-Path -Parent $PSScriptRoot
Describe 'SQL Server secret handling' {
  It 'uses SQL Server provider secrets and excludes populated secrets' {
    $example = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/secrets.example.json') | ConvertFrom-Json
    $example.database.provider | Should -Be 'SQLSERVER'
    $example.database.sqlServer.saPassword | Should -Be ''
    (Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot '.gitignore')) | Should -Match 'secrets.json'
  }
  It 'does not place the SA password in ordinary manifest generation' {
    $generator = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'Generate-Package.ps1')
    $generator | Should -Not -Match 'saPassword'
    $generator | Should -Match 'secretsIncluded = \$false'
  }
}
