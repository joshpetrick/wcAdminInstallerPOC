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

## Directory setup

The generated package creates missing non-media directories under `C:\WindchillFoundationPOC`: `Cache`, `Builds`, `Output`, and `MockYDrive`. It never fabricates Oracle media.

## Generate the package

```powershell
pwsh ./Generate-Package.ps1 -ProfilePath ./profiles/windchill-12.1.2.json -OutputDirectory ./output
```

Expected generated files include `wc-12.1.2-foundation-build-0.1.0/`, `wc-12.1.2-foundation-build-0.1.0.zip`, and `.sha256`. The package contract is designed so a future hosted Admin app can replace profile selection while preserving the build ZIP layout. The generated package is self-contained and can run from an extracted ZIP in a directory with no source-control metadata.

## Run, resume, and clean

Extract the ZIP, run `pwsh ./Start-Foundation-Build.ps1`, populate the generated `secrets.json`, then rerun. Resume with `pwsh ./Resume-Foundation-Build.ps1 -BuildDirectory <path>`. Clean with `pwsh ./Clean-Foundation-Build.ps1 -BuildDirectory <path>` or add `-Force` for noninteractive cleanup.

## Output and publication

A completed integration run produces `wc-12.1.2-foundation-virtualbox-0.1.0.box`, checksum, `foundation-manifest.json`, validation reports, and `build.log`, then copies them to `C:\WindchillFoundationPOC\MockYDrive\Foundations\wc-12.1.2\0.1.0\virtualbox`. Do not run active VMs from the mock shared repository.

## Troubleshooting and security

Failures stop at the first stage, preserve VMs/logs/markers, and print resume and cleanup commands. Logs are redacted where scripts control output. Do not commit Oracle binaries, generated VM images, response files, logs, or passwords. The `.gitignore` file enforces public-repository protections and does not make Git a runtime dependency.

## Compatibility and future mapping

AlmaLinux 8 is an account-free RHEL 8-compatible POC OS and is not represented as PTC-certified. Windchill 12.1.2.0 is a compatibility target only; Windchill is not installed. VMware support can be added by isolating provider-specific Vagrant and packaging logic while keeping profile, manifest, validation, and publication contracts stable.
