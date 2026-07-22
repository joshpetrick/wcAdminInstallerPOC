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

  It 'Vagrantfile resizes the primary disk without storage controller customizations' {
    $vagrantfile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Vagrantfile.template')
    $vagrantfile | Should -Match 'config.vm.disk :disk, size: disk_size, primary: true'
    $vagrantfile | Should -Not -Match "'storagectl'|'storageattach'|SATA Controller|Windchill Foundation Data"
  }

  It 'runtime launcher copies package contents without wildcard LiteralPath and validates Vagrantfile before vagrant up' {
    $launcher = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Start-Foundation-Build.ps1')
    $launcher | Should -Match 'Get-ChildItem -LiteralPath \$SourceDirectory'
    $launcher | Should -Match 'Assert-FileExists .*Vagrantfile'
    $launcher | Should -Match '\$versionLabel = \$p.windchillVersion.Substring\(0,6\)'
    $launcher | Should -Match 'wc-\$versionLabel-foundation-virtualbox'
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

  It 'generator normalizes generated shell scripts to Unix LF endings before zipping' {
    $generatorText = Get-Content -Raw -LiteralPath $script:generator
    $generatorText | Should -Match 'Convert-GeneratedShellScriptsToLf'
    $generatorText | Should -Match "-Include '\*.sh'"
    $generatorText | Should -Match 'WriteAllText'
  }

  It 'stage wrapper streams failures to console and prepare-linux has AlmaLinux prerequisite fallback' {
    $common = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/common.sh')
    $prepare = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/01-prepare-linux.sh')
    $common | Should -Match 'tee -a "\$log"'
    $common | Should -Match 'Last 80 log lines'
    $prepare | Should -Match 'oracle-database-preinstall-19c was not available'
    $prepare | Should -Match 'glibc-static'
    $prepare | Should -Match 'ensure_legacy_libnsl'
    $prepare | Should -Match 'libnsl.so.1'
    $prepare | Should -Match 'groupadd -f'
  }

  It 'prepare-linux disables guest graphical UI for headless dev images' {
    $profile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'profiles/windchill-12.1.2.json') | ConvertFrom-Json
    $vagrantfile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Vagrantfile.template')
    $prepare = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/01-prepare-linux.sh')
    $profile.vm.headless | Should -BeTrue
    $vagrantfile | Should -Match "vb.gui = !cfg\['vm'\]\['headless'\]"
    $prepare | Should -Match 'configure_headless'
    $prepare | Should -Match 'systemctl set-default multi-user.target'
    $prepare | Should -Match 'display-manager.service'
    $prepare | Should -Match 'systemctl mask'
  }

  It 'Java install uses the profile major version instead of hard-coded Corretto 11' {
    $installJava = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/02-install-java.sh')
    $installJava | Should -Match "json '\.profile\.java\.majorVersion'"
    $installJava | Should -Match 'java-\$\{java_major\}-amazon-corretto-devel'
    $installJava | Should -Not -Match 'java-11-amazon-corretto-devel'
  }

  It 'Vagrantfile copies Oracle media with file provisioner and stage 03 uses guest-local media path' {
    $vagrantfile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Vagrantfile.template')
    $prepareOracle = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/03-prepare-oracle.sh')
    $vagrantfile | Should -Match "config.vm.provision 'file'"
    $vagrantfile | Should -Match 'oracle_media_path'
    $prepareOracle | Should -Match '/tmp/windchill-foundation-oracle-media'
    $prepareOracle | Should -Not -Match 'C:\\WindchillFoundationPOC'
  }

  It 'Oracle media staging directory is writable by Vagrant file provisioner' {
    $vagrantfile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Vagrantfile.template')
    $vagrantfile | Should -Match 'chmod 0777 #\{oracle_guest_media_dir\}'
    $vagrantfile | Should -Match "config.vm.provision 'file'"
  }

  It 'launcher failure output prints log resume and cleanup commands on separate lines' {
    $launcher = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/Start-Foundation-Build.ps1')
    $launcher | Should -Match 'Log command:'
    $launcher | Should -Match 'Resume command:'
    $launcher | Should -Match 'Cleanup command:'
    $launcher | Should -Match '\[Environment\]::NewLine'
  }

  It 'Oracle install applies CV_ASSUME_DISTID workaround for AlmaLinux Oracle 19.3 installer' {
    $profile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'profiles/windchill-12.1.2.json') | ConvertFrom-Json
    $common = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/common.sh')
    $installOracle = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/04-install-oracle.sh')
    $profile.oracle.assumedDistribution | Should -Be 'OEL7.8'
    $common | Should -Match 'CV_ASSUME_DISTID'
    $installOracle | Should -Match 'cvu_config'
    $installOracle | Should -Match 'runInstaller'
  }

  It 'Oracle install response supplies all privileged OS groups required by 19c silent installer' {
    $response = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/oracle/db_install.rsp.template')
    foreach ($field in @('OSDBA_GROUP','OSBACKUPDBA_GROUP','OSDGDBA_GROUP','OSKMDBA_GROUP','OSRACDBA_GROUP')) {
      $response | Should -Match $field
    }
  }

  It 'Oracle database and listener responses disable optional UI and security extras' {
    $dbca = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/oracle/dbca.rsp.template')
    $netca = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/oracle/netca.rsp.template')
    $dbca | Should -Match 'emConfiguration=NONE'
    $dbca | Should -Match 'sampleSchema=false'
    $dbca | Should -Match 'dvConfiguration=false'
    $dbca | Should -Match 'olsConfiguration=false'
    $netca | Should -Match 'INSTALLED_COMPONENTS=\{"server","net8"\}'
    $netca | Should -Not -Match 'javavm'
  }

  It 'Oracle listener and services use resolvable host and explicit Oracle runtime environment' {
    $prepare = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/01-prepare-linux.sh')
    $listener = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/05-configure-listener.sh')
    $services = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/07-configure-services.sh')
    $validate = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/08-validate-foundation.sh')
    $prepare | Should -Match 'ip -4 route get 1.1.1.1'
    $prepare | Should -Match 'echo "\$primary_ip \$vm_hostname" >> /etc/hosts'
    $listener | Should -Match 'runuser -u "\$oracle_user"'
    $listener | Should -Match "PATH='\$ORACLE_HOME/bin'"
    $validate | Should -Match 'runuser -u "\$oracle_user"'
    $validate | Should -Match "PATH='\$ORACLE_HOME/bin'"
    $services | Should -Match 'windchill-listener-start.sh'
    $services | Should -Match 'Oracle listener is already running'
    $services | Should -Match 'Type=oneshot'
    $services | Should -Match 'RemainAfterExit=yes'
    $services | Should -Match 'windchill-oracle-start.sh'
    $services | Should -Match 'select status from v'
    $services | Should -Match 'instance'
    $services | Should -Match 'TimeoutStartSec=900'
  }

  It 'Oracle database creation is bounded and emits heartbeat diagnostics' {
    $profile = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'profiles/windchill-12.1.2.json') | ConvertFrom-Json
    $createDatabase = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/06-create-database.sh')
    $profile.oracle.databaseCreationTimeoutMinutes | Should -Be 90
    $profile.oracle.databaseCreationHeartbeatSeconds | Should -Be 120
    $createDatabase | Should -Match 'timeout --kill-after=5m'
    $createDatabase | Should -Match 'DBCA is still running'
    $createDatabase | Should -Match 'DBCA exceeded the configured'
    $createDatabase | Should -Match 'DBCA completed with warnings'
    $createDatabase | Should -Match 'verify_database_open'
    $createDatabase | Should -Match 'OPEN_MODE='
    $createDatabase | Should -Match 'dump_dbca_logs'
  }

  It 'Oracle install treats runInstaller exit code 6 as success with warnings' {
    $installOracle = Get-Content -Raw -LiteralPath (Join-Path $script:repoRoot 'package-template/scripts/04-install-oracle.sh')
    $installOracle | Should -Match 'installer_rc'
    $installOracle | Should -Match 'installer_rc -eq 6'
    $installOracle | Should -Match 'completed with warnings'
    $installOracle | Should -Match 'ignorePrereqFailure'
  }

  It 'excludes media and populated secrets' {
    $out = Join-Path $TestDrive 'safe out'
    & $script:generator -ProfilePath $script:profile -OutputDirectory $out -Force
    Get-ChildItem -Recurse (Join-Path $out $script:name) | ForEach-Object Name | Should -Not -Contain 'secrets.json'
    Get-ChildItem -Recurse (Join-Path $out $script:name) | ForEach-Object Name | Should -Not -Contain 'LINUX.X64_193000_db_home.zip'
  }
}
