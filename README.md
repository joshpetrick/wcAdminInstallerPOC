# Windchill 12.1.2 Foundation Image Builder POC

This repository implements the local package-generation and execution portion of a future Admin Image Builder. It is admin-only: administrators provide Oracle 19c media, generate a build ZIP, run it on Windows with PowerShell 7, Vagrant, and VirtualBox, and publish a validated `.box` to a mock shared directory. Developers later consume only the completed foundation image and do not download Oracle.

Git may be used by contributors to work with this source repository, but it is not used or required by the package generator or generated Admin build package.

```text
Foundation profile JSON
        ↓
Generate-Package.ps1
        ↓
Admin build-package ZIP
        ↓
Administrator runs package locally
        ↓
Vagrant
        ↓
VirtualBox
        ↓
AlmaLinux + Corretto 11 + Oracle 19c
        ↓
Validation
        ↓
Sanitization
        ↓
Reusable VirtualBox .box
        ↓
Mock shared repository
        ↓
Future developers consume completed foundation
```

## Scope and exclusions

Included: profile configuration, package generation, local VirtualBox/Vagrant execution, AlmaLinux provisioning, Amazon Corretto 11, Oracle 19c software-only install, listener/CDB/PDB creation, validation, sanitization, Vagrant `.box` packaging, packaged-box verification hook, and mock Y-drive publication layout. Excluded: source-repository creation, hosted web apps, Spring Boot, Admin/Developer UI, Windchill install, PSI/CPS/module selection, VMware, Packer, Ansible, Docker, WSL, auth, databases for configuration, real Y-drive connectivity, and developer environment creation.

## Prerequisites

Required on the Windows Admin build computer:

- Oracle VirtualBox
- HashiCorp Vagrant CLI
- PowerShell 7
- Hardware virtualization enabled

Admin media prerequisite:

- Oracle Database 19c Linux x86-64 installation ZIP

Not required on Windows:

- Git
- Java
- Oracle Database
- Oracle Client
- Docker
- WSL
- Packer
- Ansible

Download `LINUX.X64_193000_db_home.zip` yourself to `C:\WindchillFoundationPOC\Media\Oracle`. The default SHA-256 is `ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8`. Oracle media is required only for admin image creation: the final `.box` preserves installed Oracle software and a clean database while sanitization removes installer ZIPs and extracted install media.

## Directory contexts

### Repository location

The source repository may be any local folder, for example:

```text
C:\Users\petri\IdeaProjects\wcAdminInstallerPOC
```

Run package generation from this repository. Repository-owned files such as `package-template`, `profiles`, `schemas`, and `tests` are resolved from the generator script location, not from `C:\WindchillFoundationPOC`.

### Generated package output

By default, package output is created beneath the repository:

```text
<repository>\output
```

A relative `-OutputDirectory .\output` resolves under the repository root so generation is consistent even if the shell starts elsewhere.

### Foundation runtime workspace

The generated package creates missing non-media runtime directories under `C:\WindchillFoundationPOC`: `Cache`, `Builds`, `Output`, and `MockYDrive`. This workspace is used when the generated Admin build package is executed for Oracle media, cache, temporary VM builds, final artifacts, and mock Y-drive publication. It is not the source-code location, and the generator never fabricates Oracle media.

## Generate the package

```powershell
cd C:\Users\petri\IdeaProjects\wcAdminInstallerPOC
pwsh

.\Generate-Package.ps1 `
    -ProfilePath .\profiles\windchill-12.1.2.json `
    -OutputDirectory .\output `
    -Force
```

`-Force` replaces only the deterministic generated package directory, ZIP, checksum, and generation report for this package. It does not delete the output root, source templates, profiles, schemas, Oracle media, or runtime workspace directories.

Expected generated files include `wc-12.1.2-foundation-build-0.1.0/`, `wc-12.1.2-foundation-build-0.1.0.zip`, and `.sha256`. The package contract is designed so a future hosted Admin app can replace profile selection while preserving the build ZIP layout. After generation, run the package from the generated directory or from an extracted ZIP. The generated package is self-contained and can run from an extracted ZIP in a directory with no source-control metadata.


## Procedure: build the Admin foundation package and image

Follow these steps in order. The source repository and the runtime workspace are intentionally different directories.

### Step 1: Verify prerequisites

On the Windows Admin build computer, confirm that these are installed and available:

1. Oracle VirtualBox.
2. HashiCorp Vagrant CLI.
3. PowerShell 7 (`pwsh`).
4. Hardware virtualization enabled in BIOS/UEFI.
5. Oracle Database 19c Linux x86-64 installer ZIP staged at the configured media path.

The default Oracle media path is:

```text
C:\WindchillFoundationPOC\Media\Oracle\LINUX.X64_193000_db_home.zip
```

### Step 2: Open PowerShell in the source repository

Example repository location:

```powershell
cd C:\Users\petri\IdeaProjects\wcAdminInstallerPOC
pwsh
```

### Step 3: Generate the Admin build package

Run:

```powershell
.\Generate-Package.ps1 `
    -ProfilePath .\profiles\windchill-12.1.2.json `
    -OutputDirectory .\output `
    -Force
```

This creates the package directory and ZIP under `<repository>\output`. `-Force` is safe for regeneration because it removes only this package's deterministic package directory, ZIP, checksum, and generation report.

### Step 4: Enter the generated package directory

```powershell
cd .\output\wc-12.1.2-foundation-build-0.1.0
```

Alternatively, extract `wc-12.1.2-foundation-build-0.1.0.zip` somewhere else and open PowerShell in the extracted folder.

### Step 5: Create and populate secrets

Run the build launcher once:

```powershell
.\Start-Foundation-Build.ps1
```

If `secrets.json` does not exist, the launcher creates it from `secrets.example.json` and stops. Edit `secrets.json`, populate the Oracle SYS, SYSTEM, and PDB admin passwords, save the file, and rerun the launcher. Do not commit or share `secrets.json`.

### Step 6: Start the foundation build

From the generated package directory, rerun:

```powershell
.\Start-Foundation-Build.ps1
```

The launcher validates host prerequisites and Oracle media, creates the runtime workspace under `C:\WindchillFoundationPOC`, starts Vagrant with the VirtualBox provider, and runs the Linux provisioning stages.

### Step 7: Resume after a failed stage

If a stage fails, keep the VM and logs in place and run the resume command printed by the launcher. The command has this shape:

```powershell
.\Resume-Foundation-Build.ps1 -BuildDirectory "C:\WindchillFoundationPOC\Builds\<build-folder>"
```

### Step 8: Clean a failed or unwanted build

Cleanup requires confirmation unless `-Force` is supplied. Use the build directory printed by the failed launcher. Do not include a trailing backslash before the closing quote.

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory "C:\WindchillFoundationPOC\Builds\<build-folder>"
```

For noninteractive cleanup:

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory "C:\WindchillFoundationPOC\Builds\<build-folder>" -Force
```

The cleanup script now handles incomplete build folders: if no `Vagrantfile` exists it skips `vagrant destroy` and removes the failed build directory only.

### Step 9: Collect successful output

After a successful full integration run, final artifacts are copied to the mock shared repository path:

```text
C:\WindchillFoundationPOC\MockYDrive\Foundations\wc-12.1.2\0.1.0\virtualbox
```

Expected artifacts include the `.box`, checksum, foundation manifest, validation reports, and build log.

## Run, resume, and clean

Extract the ZIP, run `pwsh ./Start-Foundation-Build.ps1`, populate the generated `secrets.json`, then rerun. Resume with `pwsh ./Resume-Foundation-Build.ps1 -BuildDirectory <path>`. Clean with `pwsh ./Clean-Foundation-Build.ps1 -BuildDirectory <path>` or add `-Force` for noninteractive cleanup.

## Output and publication

A completed integration run produces `wc-12.1.2-foundation-virtualbox-0.1.0.box`, checksum, `foundation-manifest.json`, validation reports, and `build.log`, then copies them to `C:\WindchillFoundationPOC\MockYDrive\Foundations\wc-12.1.2\0.1.0\virtualbox`. Do not run active VMs from the mock shared repository.

## Troubleshooting and security

Failures stop at the first stage, preserve VMs/logs/markers, and print resume and cleanup commands. Logs are redacted where scripts control output. Do not commit Oracle binaries, generated VM images, response files, logs, or passwords. The `.gitignore` file enforces public-repository protections and does not make Git a runtime dependency.


### Vagrant says no environment or target machine is required

If Vagrant prints this message:

```text
A Vagrant environment or target machine is required to run this command.
```

it means `vagrant up` was executed from a folder that does not contain a `Vagrantfile`. You do not need to run `vagrant init`. Run `Start-Foundation-Build.ps1` from the generated package directory, for example:

```powershell
cd .\output\wc-12.1.2-foundation-build-0.1.0
.\Start-Foundation-Build.ps1
```

The launcher copies the generated package into an isolated build directory under `C:\WindchillFoundationPOC\Builds` and verifies that `Vagrantfile` is present before running `vagrant up`. If this fails, inspect the `build.log` path printed in the error message and verify that the generated package contains `Vagrantfile` and `config.json`.


### VirtualBox says it could not find `SATA Controller`

Older generated packages attempted to add or attach a second VirtualBox SATA controller. Some AlmaLinux base-box versions already have the maximum number of SATA controllers, or use a controller name that differs from earlier assumptions, which causes `VBoxManage storagectl` or `storageattach` to fail before boot. Regenerate the Admin package after this fix so the generated `Vagrantfile` uses Vagrant VirtualBox disk support to resize the primary disk to the configured size instead of depending on any base-box storage-controller name.

Recommended recovery after seeing this error:

```powershell
# From the generated package folder that failed
.\Clean-Foundation-Build.ps1 -BuildDirectory "C:\WindchillFoundationPOC\Builds\<failed-build-folder>" -Force

# From the source repository
cd C:\Users\petri\IdeaProjects\wcAdminInstallerPOC
.\Generate-Package.ps1 `
    -ProfilePath .\profiles\windchill-12.1.2.json `
    -OutputDirectory .\output `
    -Force

cd .\output\wc-12.1.2-foundation-build-0.1.0
.\Start-Foundation-Build.ps1
```



### Provisioning fails with `set: pipefail: invalid option name`

This usually means a Linux shell script reached the guest with Windows CRLF line endings. Regenerate the Admin package after this fix; the generator normalizes all generated `*.sh` files to Unix LF before creating the ZIP. If you already have a failed build directory, clean it, regenerate the package, and start from the new generated package directory.


### Stage `01-prepare-linux` fails without details in Vagrant output

The provisioning wrapper now streams each stage command to both the console and `/var/lib/windchill-foundation/logs/<stage>.log`, and prints the last 80 log lines when a stage fails. Older generated packages redirected stage output only to the guest log, which made Vagrant show only a generic non-zero exit message.

For AlmaLinux, the Oracle Linux convenience package `oracle-database-preinstall-19c` may not be available from enabled repositories. Stage 01 now falls back to explicit Oracle 19c prerequisite packages and creates the Oracle user/groups directly when that package is unavailable.

### Linux desktop UI should stay disabled

The default profile already runs VirtualBox headless, and stage `01-prepare-linux` also forces the guest into `multi-user.target` before package installation. It disables and masks common display manager units (`display-manager`, `gdm`, `lightdm`, and `sddm`) if any are present in the AlmaLinux base box, so the development image does not boot a graphical Linux UI that users do not need. This keeps the existing CPU and memory defaults unchanged while avoiding guest-side desktop services when the base box includes them.


### Stage `03-prepare-oracle` cannot find `C:\WindchillFoundationPOC\Media\Oracle` inside Linux

Windows host paths such as `C:\WindchillFoundationPOC\Media\Oracle` do not exist inside the AlmaLinux guest. The generated `Vagrantfile` now validates the configured Oracle installer path on the Windows host and uses Vagrant's file provisioner to copy only that ZIP into `/tmp/windchill-foundation-oracle-media/` inside the guest before stage `03-prepare-oracle` runs. The ZIP is then copied to guest-local installer staging and checksum-validated. Oracle media is still not included in the generated Admin ZIP or source repository.


### Oracle media upload fails with SCP permissions error

The Oracle media file provisioner copies the ZIP as the Vagrant SSH user. The guest staging directory is intentionally created under `/tmp/windchill-foundation-oracle-media` with relaxed write permissions for this local development-image POC so the upload can succeed. The ZIP is still copied only from the configured host media path, checksum-validated in the guest, and removed during sanitization.


### Oracle installer fails with `[INS-08101] supportedOSCheck`

Oracle Database 19.3 can throw `[INS-08101]` with a Java `NullPointerException` during `supportedOSCheck` on RHEL-compatible 8.x distributions. The POC now applies the standard compatibility workaround for every AlmaLinux build by setting `CV_ASSUME_DISTID` from the profile, defaulting to `OEL7.8`, before running the Oracle installer and by writing the same value into `$ORACLE_HOME/cv/admin/cvu_config` after the installer ZIP is extracted. This is a POC workaround for Oracle 19.3 base media; no Release Update is applied in this POC.


### Oracle installer fails with `[INS-35344]` missing privileged OS groups

Oracle 19c silent install validates all privileged OS group response-file fields, including OSBACKUPDBA, OSDGDBA, OSKMDBA, and OSRACDBA. For this local single-instance development-image POC, these groups are all mapped to the configured `dba` group in `db_install.rsp.template`. This is intentionally simple and can be split into separate groups later if the hosted Admin builder needs stricter production-style separation.


### Oracle installer reports `Successfully Setup Software with warning(s)` and exits with code `6`

Oracle Database 19.3 silent install can return exit code `6` after a successful software-only setup when optional prerequisite warnings are ignored. This POC intentionally runs the installer with `-ignorePrereqFailure` on AlmaLinux because the base Oracle 19.3 media is being used on an AlmaLinux development image. Stage `04-install-oracle` now treats exit code `6` as success-with-warnings, continues with `orainstRoot.sh` and `root.sh`, and still fails for other non-zero installer exit codes. If a prior build stopped at stage `04`, clean that incomplete build or regenerate the package and retry so the updated stage script is used.


### Oracle install and database creation are slow

Oracle's software-only installer lays down the Enterprise Edition database home from the official 19.3 media, so there is no reliable response-file switch in this POC to remove arbitrary database-home components without risking Windchill compatibility. The POC keeps the database runtime leaner by disabling Enterprise Manager (`emConfiguration=NONE`), sample schemas (`sampleSchema=false`), Database Vault (`dvConfiguration=false`), Oracle Label Security (`olsConfiguration=false`), and NetCA JavaVM listener registration. Components that Windchill commonly relies on or that Oracle includes as part of the base home, such as core RDBMS, networking, JVM support, XML, and text/spatial-capable libraries, are left installed to keep the foundation image broadly compatible.


### NetCA says `No valid IP Address returned for the host` or `lsnrctl` is not found

Stage `01-prepare-linux` now maps the configured VM hostname to the guest's primary IPv4 address in `/etc/hosts` instead of using a loopback-only entry, which allows NetCA to resolve `wc121-foundation` to a usable listener address. Stage `05-configure-listener` also runs NetCA and `lsnrctl` through `runuser` with explicit `ORACLE_HOME`, `ORACLE_BASE`, `ORACLE_SID`, and `PATH` exports so Oracle tools are found even when a login shell does not preserve the root provisioning environment.

### Stage `07-configure-services` times out after DBCA already created the database

Stage `06-create-database` can legitimately spend a while at `Creating Pluggable Databases`, but it should not be silent for hours. The stage now runs DBCA with `profile.oracle.databaseCreationTimeoutMinutes` (default `90`) and prints heartbeat lines every `profile.oracle.databaseCreationHeartbeatSeconds` (default `120`) while DBCA is still running. If DBCA times out or exits non-zero, the stage prints recent DBCA logs before failing so the next retry has actionable details instead of appearing hung.

DBCA leaves the new database running at the end of stage `06-create-database`, and stage `05-configure-listener` already starts the listener. Stage `07-configure-services` now installs idempotent listener and database start/stop helper scripts, then registers them as `oneshot` systemd units with `RemainAfterExit=yes`. The listener helper treats an already-running listener as success, and the database start helper checks `v$instance` and starts the instance only when it is not already open, then opens and saves all PDB state. The systemd startup timeout is extended for the database service to accommodate first-boot CDB/PDB startup on slower developer hosts without changing CPU or memory defaults. The `ΓåÆ` characters sometimes shown in Vagrant output are the Windows console rendering of systemd's symlink arrow and are not written into the service files.

## Compatibility and future mapping

AlmaLinux 8 is an account-free RHEL 8-compatible POC OS and is not represented as PTC-certified. Windchill 12.1.2.0 is a compatibility target only; Windchill is not installed. VMware support can be added by isolating provider-specific Vagrant and packaging logic while keeping profile, manifest, validation, and publication contracts stable.
