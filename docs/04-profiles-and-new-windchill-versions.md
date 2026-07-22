# 04 - Profiles and new Windchill versions

Profiles are JSON files under `profiles/`. They describe the compatibility target, VM sizing, OS base box, Java runtime, Oracle configuration, and Windows runtime paths.

## Current profile

The checked-in profile is:

```text
profiles\windchill-12.1.2.json
```

It targets:

```json
"windchillVersion": "12.1.2.0"
```

The status is intentionally:

```json
"compatibilityStatus": "POC_NOT_CERTIFIED"
```

That means the profile is a POC compatibility target, not a certification statement.

## Create a profile for 13.1.2

Start by copying the existing profile:

```powershell
Copy-Item .\profiles\windchill-12.1.2.json .\profiles\windchill-13.1.2.json
```

Edit the new file and update at least these fields:

| Field | 12.1.2 example | 13.1.2 example | Notes |
| --- | --- | --- | --- |
| `profileId` | `windchill-12.1.2-foundation` | `windchill-13.1.2-foundation` | Must identify the target clearly. |
| `displayName` | `Windchill 12.1.2 Foundation POC` | `Windchill 13.1.2 Foundation POC` | Human-readable label. |
| `windchillVersion` | `12.1.2.0` | `13.1.2.0` | Drives package and box naming. |
| `artifactVersion` | `0.1.0` | `0.1.0` or higher | Increment when rebuilding the same target. |
| `vm.name` | `wc121-foundation-build` | `wc131-foundation-build` | Avoid VirtualBox VM name collisions. |
| `vm.hostname` | `wc121-foundation` | `wc131-foundation` | Avoid hostname ambiguity. |

The generated package name uses the first three version components. For `13.1.2.0`, expect:

```text
wc-13.1.2-foundation-build-0.1.0
wc-13.1.2-foundation-virtualbox-0.1.0.box
```

## Revisit platform requirements

Before calling a new profile supported, verify the target Windchill version's requirements outside this POC:

- Supported Java major version and vendor.
- Supported Oracle database version and patch level.
- Supported operating system family and version.
- Required database character set, national character set, CDB/PDB requirements, and service naming.
- Any Windchill-specific database options or init parameters.

Do not blindly assume that 13.1.2 uses the exact same foundation requirements as 12.1.2.

## Generate with the new profile

```powershell
.\Generate-Package.ps1 `
    -ProfilePath .\profiles\windchill-13.1.2.json `
    -OutputDirectory .\output `
    -Force
```

Then run the generated 13.1.2 package:

```powershell
cd .\output\wc-13.1.2-foundation-build-0.1.0
.\Start-Foundation-Build.ps1
```

## Fields that usually should not change casually

| Field | Why |
| --- | --- |
| `provider` | Only `virtualbox` is implemented. |
| `compatibilityStatus` | The generator expects `POC_NOT_CERTIFIED` for this POC. |
| `oracle.installerFilename` and `oracle.installerSha256` | Must match the actual Oracle media being used. |
| `oracle.assumedDistribution` | Workaround for Oracle 19.3 installer checks on AlmaLinux; changing it can break install. |
| `paths.*` | These control the Windows runtime workspace; keep them consistent unless documenting a new workspace standard. |

## Validation expectation for a new profile

A new profile should be accepted only after:

1. The package generator succeeds.
2. A full Vagrant build succeeds.
3. The produced `.box` boots as a consumer VM.
4. `vagrant ssh -c 'java -version'` works.
5. `sudo systemctl is-active oracle-listener oracle-database` reports active services.
6. Oracle local SYSDBA connection works and the expected PDB opens.
