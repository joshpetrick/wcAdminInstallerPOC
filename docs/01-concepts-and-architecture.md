# 01 - Concepts and architecture

## Goal

The Windchill Foundation Image Builder POC creates a reusable VirtualBox `.box` image that already contains the foundation operating system, Java runtime, Oracle software, listener, and a clean Oracle database. The intent is to let an administrator do the licensed Oracle work once, then share a sanitized foundation image for later development workflows.

## What this POC includes

- Deterministic PowerShell package generation from a JSON profile.
- A generated Admin build package that does not require Git.
- Vagrant and VirtualBox orchestration.
- AlmaLinux 8 guest provisioning.
- Headless guest operation; no Linux desktop UI is expected or needed.
- Amazon Corretto 11 installation.
- Oracle Database 19c software-only install from administrator-provided media.
- Listener and CDB/PDB creation.
- Basic validation, sanitization, and `vagrant package` output.

## What this POC does not include

- Windchill installation.
- PSI/CPS/module selection.
- A hosted Admin UI.
- Developer environment creation.
- VMware/Packer/Ansible/Docker/WSL flows.
- A real shared Y-drive or artifact repository publication service.
- PTC certification claims.

## Artifact flow

```text
Profile JSON
   ↓
Generate-Package.ps1
   ↓
Generated Admin build package ZIP
   ↓
Administrator runs Start-Foundation-Build.ps1
   ↓
Vagrant creates a VirtualBox VM
   ↓
Provisioning installs OS prerequisites, Java, Oracle, listener, and database
   ↓
Validation and sanitization run
   ↓
vagrant package creates a reusable .box
   ↓
Administrator adds/tests/publishes the .box for downstream use
```

## Important directory distinction

Do not mix these locations:

| Location | Example | Purpose |
| --- | --- | --- |
| Source repository | `C:\Users\petri\IdeaProjects\wcAdminInstallerPOC` | Maintained code, templates, profiles, tests, docs. |
| Generated package | `<repo>\output\wc-12.1.2-foundation-build-0.1.0` | Self-contained package admins run. |
| Runtime workspace | `C:\WindchillFoundationPOC` | Oracle media, Vagrant build folders, logs, and box outputs. |
| Build folder | `C:\WindchillFoundationPOC\Builds\wc121-foundation-build-<timestamp>` | One actual Vagrant environment and final `.box`. |

## Version naming

For a profile with `windchillVersion` of `12.1.2.0` and `artifactVersion` of `0.1.0`, generated names use the short Windchill version `12.1.2`:

```text
wc-12.1.2-foundation-build-0.1.0
wc-12.1.2-foundation-virtualbox-0.1.0.box
```

For `13.1.2.0`, the same convention becomes:

```text
wc-13.1.2-foundation-build-0.1.0
wc-13.1.2-foundation-virtualbox-0.1.0.box
```
