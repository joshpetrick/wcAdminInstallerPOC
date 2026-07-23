# Windchill Admin Foundation Image Builder POC

This repository contains a proof-of-concept Admin package generator for building reusable VirtualBox/Vagrant foundation images. The generated package is self-contained and can run without Git. The project now uses a **database-provider architecture** so the Admin profile selects a provider and the generated package includes only the provider implementation needed for that build.

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
