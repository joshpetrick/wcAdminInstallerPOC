# 06 - Security and credentials

## Oracle media

Oracle media is administrator-provided and licensed separately. It must exist on the Windows build computer at the configured media path, but it is not committed to Git and is not included in the generated Admin ZIP.

The Vagrant file provisioner uploads only the configured installer ZIP to a temporary guest staging folder. Sanitization removes installer staging from the guest before packaging the box.

## secrets.json

The generated package contains `secrets.example.json` with empty values. On first run, `Start-Foundation-Build.ps1` creates `secrets.json` and stops. You must populate:

```json
{
  "oracleSysPassword": "...",
  "oracleSystemPassword": "...",
  "oraclePdbAdminPassword": "..."
}
```

Rules:

- Do not commit `secrets.json`.
- Do not place `secrets.json` in shared artifact folders.
- Use build-only passwords for this POC.
- Rotate/rebuild if secrets are exposed.

## Linux users

| User | Notes |
| --- | --- |
| `vagrant` | Default Vagrant SSH user. Access uses VM-specific SSH keys, not a shared password. |
| `root` | Use `sudo` from `vagrant`; do not rely on direct root SSH. |
| `oracle` | Oracle software owner. Access with `sudo su - oracle` from `vagrant`. |

## Database users

| User | Source of password |
| --- | --- |
| `SYS` | `oracleSysPassword` in `secrets.json`. |
| `SYSTEM` | `oracleSystemPassword` in `secrets.json`. |
| `PDBADMIN` | `oraclePdbAdminPassword` in `secrets.json`. |

## SSH keys

Vagrant stores per-VM SSH material under the Vagrant environment folder:

```text
.vagrant\machines\default\virtualbox\private_key
```

Use `vagrant ssh-config` to discover the actual key and port for the active VM. Do not copy these keys into source control.

## Sanitization

The sanitization stage removes:

- Oracle installer ZIP staging.
- Temporary Oracle response files.
- Root and Oracle shell histories.
- DNF caches.
- Machine identity state.

It preserves:

- The `vagrant` user needed for Vagrant box access.
- Vagrant SSH functionality.
- Installed Oracle software.
- The created database.
- Validation metadata.

## Publication guidance

Treat a produced `.box` as an internal artifact. Before sharing it:

1. Confirm no Oracle installer ZIP remains in the guest.
2. Confirm no `secrets.json` is bundled with the box artifact folder.
3. Confirm SSH access works through Vagrant-managed keys.
4. Confirm intended consumers are authorized to use the resulting Oracle-containing image under your organization's licensing rules.
