Set-StrictMode -Version Latest
$script:repoRoot = Split-Path -Parent $PSScriptRoot
$script:generator = Join-Path $script:repoRoot 'Generate-Package.ps1'

Describe 'SQL Server provider package generation' {
  It 'renders a SQL Server package without Oracle response templates or media checks' {
    $out = Join-Path ([System.IO.Path]::GetTempPath()) ("wc-package-test-" + [guid]::NewGuid())
    try {
      & $script:generator -ProfilePath (Join-Path $script:repoRoot 'profiles/windchill-13.1.2-sqlserver.json') -OutputDirectory $out -Force
      $pkg = Get-ChildItem -LiteralPath $out -Directory | Select-Object -First 1
      $pkg.Name | Should -Match 'sqlserver'
      Test-Path (Join-Path $pkg.FullName 'scripts/database-providers/sqlserver/install.sh') | Should -BeTrue
      Test-Path (Join-Path $pkg.FullName 'scripts/database-providers/oracle/response-templates') | Should -BeFalse
      (Get-Content -Raw (Join-Path $pkg.FullName 'Vagrantfile')) | Should -Not -Match 'Oracle installer was not found'
      (Get-Content -Raw (Join-Path $pkg.FullName 'config.json')) | Should -Match '"provider":\s*"SQLSERVER"'
    } finally { Remove-Item -Recurse -Force -LiteralPath $out -ErrorAction SilentlyContinue }
  }

  It 'contains provider dispatch and SQL Server installation requirements' {
    $common = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/common.sh')
    $install = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/database-providers/sqlserver/install.sh')
    $configure = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/database-providers/sqlserver/configure.sh')
    $validate = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/database-providers/sqlserver/validate.sh')
    $common | Should -Match 'dispatch_provider'
    $install | Should -Match 'mssql-server-2022.repo'
    $install | Should -Match 'mssql-tools18'
    $configure | Should -Match 'MSSQL_SA_PASSWORD'
    $configure | Should -Not -Match 'SA_PASSWORD='
    $validate | Should -Match "SERVERPROPERTY\('ProductVersion'\)"
    $validate | Should -Match 'FoundationValidation'
  }

  It 'active SQL Server scripts contain no Oracle installer commands' {
    $active = @('01-prepare-linux.sh','02-install-java.sh','03-install-database.sh','04-configure-database.sh','05-validate-database.sh','06-reboot-validation.sh','07-sanitize-foundation.sh','08-validate-foundation.sh') |
      ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot "package-template/scripts/$_") }
    ($active -join "`n") | Should -Not -Match 'dbca|netca|lsnrctl|sqlplus|LINUX\.X64_193000_db_home\.zip|OPatch|ORACLE_HOME|ORACLE_BASE'
  }
}


Describe 'Documentation entry points' {
  It 'main README links chapter docs and cleanup command' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'README.md')
    $readme | Should -Match 'docs/01-concepts-and-architecture.md'
    $readme | Should -Match 'docs/02-admin-build-procedure.md'
    $readme | Should -Match 'docs/03-box-usage-and-ssh.md'
    $readme | Should -Match 'Clean-Foundation-Build.ps1'
    $readme | Should -Match 'Prerequisites summary'
    $readme | Should -Match 'VBoxManage'
  }

  It 'generated package README preserves cleanup and resume instructions' {
    $packageReadme = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/README.md.template')
    $packageReadme | Should -Match 'Start-Foundation-Build.ps1'
    $packageReadme | Should -Match 'Resume-Foundation-Build.ps1'
    $packageReadme | Should -Match 'Clean-Foundation-Build.ps1'
    $packageReadme | Should -Match 'Prerequisites on the Windows build host'
    $packageReadme | Should -Match '12 characters'
  }
}
