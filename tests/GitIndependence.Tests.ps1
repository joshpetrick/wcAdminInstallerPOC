Describe 'Git independence' {
  BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:runtimeFiles = Get-ChildItem -Path $script:repoRoot -Recurse -File -Include *.ps1,*.psm1,*.sh,*.template,Vagrantfile* |
      Where-Object { $_.FullName -notmatch [regex]::Escape([IO.Path]::DirectorySeparatorChar + 'tests' + [IO.Path]::DirectorySeparatorChar) }
  }

  It 'prerequisite validation does not check Git' {
    $text = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Test-Prerequisites.ps1')
    $text | Should -Not -Match 'git(\.exe)?'
    $text | Should -Match 'VBoxManage'
    $text | Should -Match 'Program Files\\Oracle\\VirtualBox'
    $text | Should -Match 'vagrant'
    $text | Should -Match 'PowerShell 7'
  }

  It 'package generation and generated runtime scripts do not invoke Git commands' {
    foreach ($file in @((Join-Path $script:repoRoot 'Generate-Package.ps1')) + $script:runtimeFiles.FullName) {
      $content = Get-Content -Raw -LiteralPath $file
      $content | Should -Not -Match '(?i)\bgit(\.exe)?\b|rev-parse|gitCommit|gitBranch|sourceCommit|repositoryRevision'
    }
  }

  It 'manifest schema contains no Git-related fields' {
    $schema = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'schemas/foundation-manifest.schema.json')
    $schema | Should -Not -Match '(?i)gitCommit|gitBranch|sourceCommit|repositoryRevision|\bgit\b'
  }

  It 'README does not list Git as required Admin software' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'README.md')
    $readme | Should -Match 'without Git'
    $readme | Should -Not -Match 'Git is required'
  }

  It '.gitignore remains present and protects sensitive/generated artifacts' {
    $ignorePath = Join-Path $script:repoRoot '.gitignore'
    Test-Path -LiteralPath $ignorePath | Should -BeTrue
    $ignore = Get-Content -Raw -LiteralPath $ignorePath
    foreach ($pattern in @('secrets.json','*.box','*.vdi','.vagrant','*.zip','*.log','*.rsp')) {
      $ignore | Should -Match ([regex]::Escape($pattern))
    }
  }
}
