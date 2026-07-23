# Windchill Admin Foundation Image Builder POC

This repository contains a proof-of-concept Admin package generator for building reusable VirtualBox/Vagrant foundation images. The generated package is self-contained and can run without Git. The project now uses a **database-provider architecture** so the Admin profile selects a provider and the generated package includes only the provider implementation needed for that build.

## Documentation entry point

Use this README as the starting point for the POC. The sections below summarize the workflow, and the linked chapters provide the detailed, step-by-step procedures. If you are new to Vagrant or this project, read the chapters in order.

| Chapter | Purpose |
| --- | --- |
| [Concepts and architecture](docs/01-concepts-and-architecture.md) | Explains the provider boundary, the active SQL Server provider, and the disabled Oracle provider. |
| [Admin build procedure](docs/02-admin-build-procedure.md) | Shows how to generate the Admin package, create `secrets.json`, start the build, resume after failures, and clean failed builds. |
| [Box usage and SSH](docs/03-box-usage-and-ssh.md) | Shows how to add/use the generated `.box`, connect with `vagrant ssh`, and connect with PuTTY. |
| [Profiles and new Windchill versions](docs/04-profiles-and-new-windchill-versions.md) | Explains the active 13.1.2 SQL Server profile and how future profiles should model provider settings. |
| [Troubleshooting](docs/05-troubleshooting.md) | Lists common build failures and the exact resume/cleanup commands to use after corrective action. |
| [Security and credentials](docs/06-security-and-credentials.md) | Documents `secrets.json`, SQL Server SA password handling, sanitization, and future credential-rotation expectations. |

### Command map

| Task | Command |
| --- | --- |
| Generate package | `pwsh .\Generate-Package.ps1 -ProfilePath .\profiles\windchill-13.1.2-sqlserver.json -OutputDirectory .\output -Force` |
| Start build from extracted package | `pwsh .\Start-Foundation-Build.ps1` |
| Resume a failed build | `pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'` |
| Clean/destroy a failed build VM | `pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '<build-dir>'` |
| Run static/Pester checks | `pwsh .\Invoke-Tests.ps1` |

`Clean-Foundation-Build.ps1` is the supported cleanup entry point for failed or unwanted build VMs. Prefer it over manually deleting build folders because it runs `vagrant destroy -f` before removing files.


## Prerequisites summary

Before running a generated SQL Server foundation package on Windows, install:

| Software/configuration | Why it is needed | Verify with |
| --- | --- | --- |
| PowerShell 7.x | Runs generator and package launchers | `pwsh --version` |
| Vagrant CLI | Creates, provisions, and packages the VM | `vagrant --version` |
| Oracle VirtualBox 7.x | Provides the VirtualBox VM provider and `VBoxManage` | `VBoxManage --version` or `& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' --version` |
| Hardware virtualization | Required for the VM to boot reliably | BIOS/UEFI VT-x or AMD-V enabled |
| Internet/repository access | Guest downloads AlmaLinux updates, Corretto, and SQL Server from package repositories | Confirm HTTPS/proxy access to required repositories |

Vagrant does not include VirtualBox. If the prerequisite check says `VBoxManage` was not found, install VirtualBox or add the VirtualBox install directory to `PATH`.

The only file the operator must configure in the generated package is `secrets.json`, created from `secrets.example.json`. For SQL Server, set `database.sqlServer.saPassword` to a strong password with at least 12 characters containing uppercase, lowercase, number, and symbol characters.

## Active POC target

| Area | Value |
| --- | --- |
| Windchill target | 13.1.2.0 |
| OS | AlmaLinux 9, minimum 9.6, later 9.x allowed |
| Database provider | `SQLSERVER` |
| Database | Microsoft SQL Server 2022 Developer Edition on Linux |
| Java | Profile-selected Amazon Corretto, currently 21 |
| Hypervisor | VirtualBox |
| Orchestration | Vagrant |
| Compatibility status | `POC_NOT_CERTIFIED` |

AlmaLinux is used as a RHEL-compatible technical POC operating system. This repository does **not** represent AlmaLinux as Microsoft-certified or PTC-certified for this exact Windchill, SQL Server, and virtualization stack. Microsoft SQL Server release history documents that SQL Server 2022 support on RHEL 9 begins with CU10, so the active SQL Server profile requires product version `16.0.4100.1` or later. This POC is technical validation, not production certification.

## Architecture

```text
Admin foundation profile
        ↓
Database provider selection
        ↓
SQLSERVER provider
        ↓
Generated Admin build package
        ↓
Vagrant + VirtualBox
        ↓
AlmaLinux 9 + Java + SQL Server 2022 Developer
        ↓
Validation and sanitization
        ↓
Reusable VirtualBox .box
        ↓
Mock shared repository
```

Future provider flow:

```text
ORACLE provider
    → requires Oracle base media, OPatch and approved RU

SQLSERVER provider
    → downloads packages from Microsoft repository
```

## Generate the Admin package

```powershell
pwsh .\Generate-Package.ps1 -ProfilePath .\profiles\windchill-13.1.2-sqlserver.json -OutputDirectory .\output -Force
```

The generated ZIP is named like:

```text
wc-13.1.2-foundation-build-sqlserver-0.1.0.zip
```

## Run the SQL Server foundation build

Extract the ZIP on the Windows build host, then run:

```powershell
pwsh .\Start-Foundation-Build.ps1
```

The first run creates `secrets.json`. Populate `database.sqlServer.saPassword` and rerun the command. SQL Server installation media does not need to be downloaded manually; SQL Server is installed from Microsoft's Linux repository inside the VM.

## What the foundation contains

The Admin foundation installs OS prerequisites, Java, SQL Server 2022 Developer Edition, SQL Server command-line tools, contained database authentication, SQL Server Agent where supported, port `1433`, and maximum SQL memory from the profile. Windchill is not installed and no Windchill database/users/schema are created. A later Developer workflow will create the Windchill database through PSI or provider-specific Developer automation.

## Provider behavior

Provider selection is data-driven by `profile.database.provider`. The future Admin application may expose choices such as Oracle and SQL Server; changing the selected profile changes generated output without requiring an application restart. For the active SQL Server package, Oracle response files, Oracle media checks, OPatch, DBCA, NetCA, listener setup, and Oracle credentials are omitted.

## Publication

Successful builds publish to the mock provider-aware repository path:

```text
C:\WindchillFoundationPOC\MockYDrive\Foundations\wc-13.1.2\0.1.0\virtualbox\sqlserver
```

Published files include the `.box`, SHA-256, `foundation-manifest.json`, `validation-report.json`, `validation-report.txt`, and `build.log`.

See `docs/` for detailed procedures, security notes, troubleshooting, profiles, SSH usage, and provider architecture.
