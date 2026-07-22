Describe 'Secret handling' {
  It 'example secrets are empty and gitignore protects populated secrets' {
    $s = Get-Content -Raw $PSScriptRoot/../package-template/secrets.example.json | ConvertFrom-Json

    $s.oracleSysPassword | Should -Be ''
    (Get-Content -Raw $PSScriptRoot/../.gitignore) | Should -Match 'secrets.json'
  }
}
