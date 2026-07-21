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

Cleanup requires confirmation unless `-Force` is supplied:

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory "C:\WindchillFoundationPOC\Builds\<build-folder>"
```

For noninteractive cleanup:

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory "C:\WindchillFoundationPOC\Builds\<build-folder>" -Force
```

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

## Compatibility and future mapping

AlmaLinux 8 is an account-free RHEL 8-compatible POC OS and is not represented as PTC-certified. Windchill 12.1.2.0 is a compatibility target only; Windchill is not installed. VMware support can be added by isolating provider-specific Vagrant and packaging logic while keeping profile, manifest, validation, and publication contracts stable.
