# 02 - Admin build procedure

This chapter is the end-to-end runbook for administrators.

## Prerequisites on the Windows build computer

Install and verify:

1. Oracle VirtualBox.
2. HashiCorp Vagrant CLI.
3. PowerShell 7 (`pwsh`).
4. Hardware virtualization enabled in BIOS/UEFI.
5. Oracle Database 19c Linux x86-64 installer ZIP staged locally.

Quick checks:

```powershell
pwsh --version
vagrant --version
VBoxManage --version
```

## Stage Oracle media

Create the media folder and copy the Oracle installer ZIP:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\WindchillFoundationPOC\Media\Oracle'
Copy-Item 'C:\Path\To\LINUX.X64_193000_db_home.zip' 'C:\WindchillFoundationPOC\Media\Oracle\'
```

Optional checksum check:

```powershell
Get-FileHash 'C:\WindchillFoundationPOC\Media\Oracle\LINUX.X64_193000_db_home.zip' -Algorithm SHA256
```

The default profile expects:

```text
ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8
```

## Generate the package

From the source repository:

```powershell
cd C:\Users\petri\IdeaProjects\wcAdminInstallerPOC
pwsh

.\Generate-Package.ps1 `
    -ProfilePath .\profiles\windchill-12.1.2.json `
    -OutputDirectory .\output `
    -Force
```

`-Force` replaces only the deterministic package directory, ZIP, checksum, and generation report for this package. It does not delete Oracle media or the runtime workspace.

## Enter the generated package

```powershell
cd .\output\wc-12.1.2-foundation-build-0.1.0
```

You may also extract the generated ZIP somewhere else and run the package from the extracted folder.

## Create secrets.json

Run once:

```powershell
.\Start-Foundation-Build.ps1
```

If `secrets.json` does not exist, the launcher copies `secrets.example.json` to `secrets.json` and stops. Edit `secrets.json`:

```json
{
  "oracleSysPassword": "ReplaceWithStrongSysPassword1",
  "oracleSystemPassword": "ReplaceWithStrongSystemPassword1",
  "oraclePdbAdminPassword": "ReplaceWithStrongPdbPassword1"
}
```

Do not commit, email, or publish `secrets.json`.

## Start the build

From the generated package directory:

```powershell
.\Start-Foundation-Build.ps1
```

The launcher validates prerequisites, creates a timestamped build folder, copies the package into it, and runs:

```powershell
vagrant up --provider=virtualbox
```

Logs are written to the build folder:

```text
C:\WindchillFoundationPOC\Builds\<build-folder>\build.log
```

Guest stage logs are written inside the VM under:

```text
/var/lib/windchill-foundation/logs
```

## Resume a failed build

If a provisioning stage fails, do not immediately delete the VM. Use the resume command printed by the launcher:

```powershell
.\Resume-Foundation-Build.ps1 -BuildDirectory 'C:\WindchillFoundationPOC\Builds\<build-folder>'
```

The stage marker system skips completed stages and reruns the failed or remaining work.

## Inspect logs from Windows

Tail the host-side Vagrant build log:

```powershell
Get-Content -Path 'C:\WindchillFoundationPOC\Builds\<build-folder>\build.log' -Tail 200
```

From inside the build folder, inspect guest logs with Vagrant SSH:

```powershell
cd 'C:\WindchillFoundationPOC\Builds\<build-folder>'
vagrant ssh -c 'sudo tail -n 120 /var/lib/windchill-foundation/logs/06-create-database.log'
```

## Clean a failed or unwanted build

Use the cleanup command printed by the launcher:

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory 'C:\WindchillFoundationPOC\Builds\<build-folder>'
```

For noninteractive cleanup:

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory 'C:\WindchillFoundationPOC\Builds\<build-folder>' -Force
```

Cleanup runs `vagrant destroy` when a Vagrantfile exists, then removes the build folder.

## Successful output

On success, the launcher halts the VM and runs `vagrant package`. The `.box` is created in the build folder:

```text
C:\WindchillFoundationPOC\Builds\<build-folder>\wc-12.1.2-foundation-virtualbox-0.1.0.box
```

Next, follow [03 - Box usage and SSH](03-box-usage-and-ssh.md) to add and test the box.
