Describe 'Package generation path handling' {
  BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:generator = Join-Path $script:repoRoot 'Generate-Package.ps1'
    $script:profile = Join-Path $script:repoRoot 'profiles/windchill-12.1.2.json'
    $script:name = 'wc-12.1.2-foundation-build-0.1.0'
  }

  It 'resolves repository templates through the generator script root when caller is outside the repository' {
    $outside = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'outside caller')
    Push-Location $outside.FullName
    try {
      & $script:generator -ProfilePath $script:profile -OutputDirectory 'relative output with spaces' -Force
    } finally { Pop-Location }
    $expected = Join-Path $script:repoRoot "relative output with spaces/$script:name"
    Test-Path -LiteralPath (Join-Path $expected 'Vagrantfile') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $expected 'config.json') | Should -BeTrue
    Remove-Item -Recurse -Force -LiteralPath (Join-Path $script:repoRoot 'relative output with spaces')
  }

  It 'has a clear missing Vagrantfile.template preflight error' {
    $scriptText = Get-Content -Raw -LiteralPath $script:generator
    $scriptText | Should -Match ([regex]::Escape('Required Vagrant template'))
    $scriptText | Should -Match ([regex]::Escape('Vagrantfile.template'))
    $scriptText | Should -Match ([regex]::Escape('Verify that the file exists under package-template'))
  }

  It 'renders template outputs to final names and does not require later rename' {
    $out = Join-Path $TestDrive 'out with spaces'
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    $pkg = Join-Path $out $script:name
    Test-Path -LiteralPath (Join-Path $pkg 'Vagrantfile') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $pkg 'README.md') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $pkg 'config.json') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $pkg 'Vagrantfile.template') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $pkg 'README.md.template') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $pkg 'config.json.template') | Should -BeFalse
  }

  It 'validates every required generated package file before creating the ZIP' {
    $scriptText = Get-Content -Raw -LiteralPath $script:generator
    $scriptText | Should -Match 'Assert-GeneratedPackageComplete'
    foreach ($required in @('scripts/common.sh','scripts/09-sanitize-foundation.sh','oracle/netca.rsp.template','validation/validate-packaged-box.sh')) {
      $scriptText | Should -Match ([regex]::Escape($required))
    }
  }

  It 'fails when output already exists without Force and safely replaces it with Force' {
    $out = Join-Path $TestDrive 'existing output'
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $sentinel = Join-Path $out 'unrelated.keep'
    'keep me' | Set-Content -LiteralPath $sentinel
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    { & $script:generator -ProfilePath $script:profile -OutputDirectory $out } | Should -Throw
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    Test-Path -LiteralPath $sentinel | Should -BeTrue
    (Get-Content -LiteralPath $sentinel) | Should -Be 'keep me'
  }

  It 'treats a single existing output artifact as an array under strict mode' {
    $out = Join-Path $TestDrive 'single existing output'
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $out "$script:name.zip.sha256") | Out-Null
    { & $script:generator -ProfilePath $script:profile -OutputDirectory $out } | Should -Throw
  }

  It 'creates deterministic outputs, checksum, and required files without VirtualBox running' {
    $out = Join-Path $TestDrive 'deterministic out'
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    Test-Path -LiteralPath (Join-Path $out "$script:name.zip") | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $out "$script:name.zip.sha256") | Should -BeTrue
    foreach ($f in 'Start-Foundation-Build.ps1','Resume-Foundation-Build.ps1','Clean-Foundation-Build.ps1','Test-Prerequisites.ps1','Vagrantfile','config.json','secrets.example.json','README.md') {
      Test-Path -LiteralPath (Join-Path $out "$script:name/$f") | Should -BeTrue
    }
  }

  It 'generated ZIP contains Vagrantfile rather than Vagrantfile.template' {
    $out = Join-Path $TestDrive 'zip out'
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    $zip = Join-Path $out "$script:name.zip"
    $extract = Join-Path $TestDrive 'zip extract'
    Expand-Archive -LiteralPath $zip -DestinationPath $extract
    Test-Path -LiteralPath (Join-Path $extract 'Vagrantfile') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $extract 'Vagrantfile.template') | Should -BeFalse
  }

  It 'Vagrantfile creates a dedicated data disk controller instead of assuming the base box SATA Controller name' {
    $vagrantfile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Vagrantfile.template')
    $vagrantfile | Should -Match 'Windchill Foundation Data'
    $vagrantfile | Should -Match "'storagectl'"
    $vagrantfile | Should -Not -Match "--storagectl','SATA Controller'|--storagectl', 'SATA Controller'"
  }

  It 'runtime launcher copies package contents without wildcard LiteralPath and validates Vagrantfile before vagrant up' {
    $launcher = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Start-Foundation-Build.ps1')
    $launcher | Should -Match 'Get-ChildItem -LiteralPath \$SourceDirectory'
    $launcher | Should -Match 'Assert-FileExists .*Vagrantfile'
    $launcher | Should -Not -Match 'Join-Path \$PSScriptRoot.*\*'
  }

  It 'cleanup prompt braces BuildDirectory variable before question mark under strict mode' {
    $cleanup = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Clean-Foundation-Build.ps1')
    $cleanup | Should -Match '\$\{resolvedBuildDirectory\}\? Type YES'
    $cleanup | Should -Not -Match '\$BuildDirectory\?'
  }

  It 'cleanup can remove incomplete build directories without a Vagrantfile' {
    $cleanup = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Clean-Foundation-Build.ps1')
    $cleanup | Should -Match 'No Vagrantfile was found'
    $cleanup | Should -Match 'Skipping vagrant destroy'
  }

  It 'excludes media and populated secrets' {
    $out = Join-Path $TestDrive 'safe out'
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    Get-ChildItem -Recurse (Join-Path $out $script:name) | ForEach-Object Name | Should -Not -Contain 'secrets.json'
    Get-ChildItem -Recurse (Join-Path $out $script:name) | ForEach-Object Name | Should -Not -Contain 'LINUX.X64_193000_db_home.zip'
  }
}
