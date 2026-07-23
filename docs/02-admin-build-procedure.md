# Admin build procedure

This chapter is the operator checklist for creating the SQL Server foundation package and running the local Vagrant/VirtualBox build.

## 1. Windows host prerequisites

Install these on the Windows Admin build computer before running the generated package:

| Requirement | Required for | How to verify |
| --- | --- | --- |
| PowerShell 7.x | Running generator and package launchers | `pwsh --version` |
| Vagrant CLI | Creating and packaging the VM | `vagrant --version` |
| Oracle VirtualBox 7.x | VirtualBox provider and `.box` packaging | `VBoxManage --version` or `& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' --version` |
| Hardware virtualization | Booting the guest VM | Confirm VT-x/AMD-V is enabled in BIOS/UEFI and Windows security policy allows virtualization. |
| Internet or repository access | Downloading AlmaLinux packages, Amazon Corretto, and Microsoft SQL Server packages inside the VM | Browser or proxy-approved access to Microsoft package endpoints and Corretto repositories. |
| Disk space | VM disk and packaged `.box` output | Keep at least the profile disk size plus room for package output. |
| Memory | Guest VM allocation | The active profile requests 12 GB for the VM. |

Vagrant and VirtualBox are separate installs. Having `vagrant` available does not guarantee `VBoxManage` is available. If `VBoxManage` is installed but not on `PATH`, the prerequisite checker also looks in common VirtualBox install locations.

## 2. Required files to configure

The source repository contains the active profile:

```text
profiles\windchill-13.1.2-sqlserver.json
```

After package generation and extraction, the generated package contains `secrets.example.json`. Copy it to `secrets.json` or run `Start-Foundation-Build.ps1` once and let it create the file for you. Then set:

```json
{
  "database": {
    "provider": "SQLSERVER",
    "sqlServer": {
      "saPassword": "<strong-password>"
    }
  }
}
```

Password guidance: use at least 12 characters and include uppercase, lowercase, number, and symbol characters. Avoid dictionary words, the username `sa`, company names, and obvious placeholders such as `Password123!`.

## 3. Generate the Admin package

```powershell
pwsh .\Generate-Package.ps1 -ProfilePath .\profiles\windchill-13.1.2-sqlserver.json -OutputDirectory .\output -Force
```

Extract `wc-13.1.2-foundation-build-sqlserver-0.1.0.zip` on the Windows build host.

## 4. Run the SQL Server foundation build

From inside the extracted package directory:

```powershell
pwsh .\Start-Foundation-Build.ps1
```

The build creates an AlmaLinux 9 VM, installs Java, installs SQL Server 2022 Developer from Microsoft repositories, validates SQL Server, sanitizes the VM, packages a `.box`, and publishes the artifact to the mock shared repository.

## 5. Recovery and cleanup

Every failed `Start-Foundation-Build.ps1` run prints three follow-up commands: a log tail command, a resume command, and a cleanup command. Use `Resume-Foundation-Build.ps1` when the VM should continue after a transient issue, such as repository access. Use `Clean-Foundation-Build.ps1` when the build should be discarded and restarted from a clean VM.

```powershell
Get-Content -Path '<build-dir>\build.log' -Tail 200
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

`Clean-Foundation-Build.ps1` is preferred over manual deletion because it invokes Vagrant destruction before removing build files.

## 6. Where logs are stored

The build creates a Windows-side build log and Linux guest stage logs. Start with the Windows log:

```powershell
Get-Content -Path '<build-dir>\build.log' -Tail 200
```

For deeper diagnostics, SSH into the build VM from the build directory and inspect the stage logs:

```powershell
cd '<build-dir>'
vagrant ssh
sudo ls -lh /var/lib/windchill-foundation/logs
sudo tail -n 200 /var/lib/windchill-foundation/logs/04-configure-database.log
sudo tail -n 200 /var/lib/windchill-foundation/logs/05-validate-database.log
sudo journalctl -u mssql-server -n 200 --no-pager
```

Do not claim a completed integration build unless Vagrant, VirtualBox, Microsoft repository access, and the full VM flow actually ran.
