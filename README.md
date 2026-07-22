# Windchill Foundation Image Builder POC

This repository contains the local Admin Image Builder proof of concept for creating a reusable VirtualBox foundation image for Windchill-compatible development work. The current checked-in profile targets **Windchill 12.1.2.0 compatibility** and builds an AlmaLinux 8 guest with Amazon Corretto 11 and Oracle Database 19c. Windchill itself is not installed by this POC.

The project has two distinct parts:

1. **Source repository**: templates, profiles, schemas, scripts, and tests used by maintainers.
2. **Generated Admin build package**: a self-contained ZIP that an administrator runs on a Windows build computer with PowerShell 7, Vagrant, VirtualBox, and locally staged Oracle media.

Git is useful for maintaining this repository, but Git is **not** required to run the generated Admin package.

## Documentation map

Use these chapters in order if you are new to Vagrant or to this build flow.

| Chapter | Purpose |
| --- | --- |
| [01 - Concepts and architecture](docs/01-concepts-and-architecture.md) | Explains what this POC does, what it does not do, and how repository, package, VM, and box artifacts relate. |
| [02 - Admin build procedure](docs/02-admin-build-procedure.md) | Step-by-step package generation, secrets setup, build, resume, cleanup, and artifact collection. |
| [03 - Box usage and SSH](docs/03-box-usage-and-ssh.md) | What to do after the `.box` is created, how to add/run it with Vagrant, how to SSH, and how to connect with PuTTY. |
| [04 - Profiles and new Windchill versions](docs/04-profiles-and-new-windchill-versions.md) | How to clone the 12.1.2 profile for a future target such as 13.1.2 and which fields must change. |
| [05 - Troubleshooting](docs/05-troubleshooting.md) | Known errors, stage failures, slow Oracle operations, DBCA warning completion, and recovery commands. |
| [06 - Security and credentials](docs/06-security-and-credentials.md) | Credentials, Oracle media handling, generated secrets, SSH keys, and sanitization expectations. |

## Quick start for experienced admins

### 1. Stage Oracle media

Download Oracle Database 19c Linux x86-64 media yourself and place it at the profile's configured media path:

```text
C:\WindchillFoundationPOC\Media\Oracle\LINUX.X64_193000_db_home.zip
```

The default expected SHA-256 is:

```text
ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8
```

Oracle media is never committed to the repository and is not embedded in the generated Admin package ZIP.

### 2. Generate the Admin build package

```powershell
cd C:\Users\petri\IdeaProjects\wcAdminInstallerPOC
pwsh

.\Generate-Package.ps1 `
    -ProfilePath .\profiles\windchill-12.1.2.json `
    -OutputDirectory .\output `
    -Force
```

Expected output includes:

```text
output\wc-12.1.2-foundation-build-0.1.0\
output\wc-12.1.2-foundation-build-0.1.0.zip
output\wc-12.1.2-foundation-build-0.1.0.zip.sha256
output\wc-12.1.2-foundation-build-0.1.0-generation-report.json
```

### 3. Run the generated package

```powershell
cd .\output\wc-12.1.2-foundation-build-0.1.0
.\Start-Foundation-Build.ps1
```

On first run the launcher creates `secrets.json` and stops. Populate the Oracle passwords in that file, then rerun:

```powershell
.\Start-Foundation-Build.ps1
```

The build creates an isolated runtime folder under:

```text
C:\WindchillFoundationPOC\Builds\<build-folder>
```

On success, the `.box` file is created in that build folder. See [Box usage and SSH](docs/03-box-usage-and-ssh.md) for adding the box to Vagrant and connecting to it.

## Runtime workspace

The default Windows runtime root is:

```text
C:\WindchillFoundationPOC
```

The generated package creates these runtime directories as needed:

| Directory | Purpose |
| --- | --- |
| `Media\Oracle` | Administrator-provided Oracle installer ZIP. |
| `Cache` | Future cache location for reusable downloads. |
| `Builds` | Per-run Vagrant/VirtualBox build directories and build logs. |
| `Output` | Future output staging location. |
| `MockYDrive` | Placeholder for a future shared repository layout. |

The current launcher packages the box in the per-run build directory and prints next-step guidance. It does not publish active VMs directly from the mock shared repository.

## Support status

This is a proof of concept, not a PTC certification statement. The profile declares `POC_NOT_CERTIFIED`, and the documentation intentionally distinguishes compatibility targeting from certified Windchill support. See [Profiles and new Windchill versions](docs/04-profiles-and-new-windchill-versions.md) before creating additional profiles.
