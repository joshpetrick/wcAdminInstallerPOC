# 05 - Troubleshooting

## First-response checklist

When a build fails:

1. Keep the failed build folder.
2. Read the last lines of `build.log`.
3. Use the printed resume command if the failure is understood.
4. Use the printed cleanup command only when you want to discard the VM.
5. Regenerate the package after pulling code changes; old generated packages do not update themselves.

Host log:

```powershell
Get-Content -Path 'C:\WindchillFoundationPOC\Builds\<build-folder>\build.log' -Tail 200
```

Guest stage log example:

```powershell
cd 'C:\WindchillFoundationPOC\Builds\<build-folder>'
vagrant ssh -c 'sudo tail -n 120 /var/lib/windchill-foundation/logs/06-create-database.log'
```

## Resume after a stage failure

```powershell
.\Resume-Foundation-Build.ps1 -BuildDirectory 'C:\WindchillFoundationPOC\Builds\<build-folder>'
```

## Clean a failed build

```powershell
.\Clean-Foundation-Build.ps1 -BuildDirectory 'C:\WindchillFoundationPOC\Builds\<build-folder>' -Force
```

## Vagrant says no environment or target machine is required

You ran `vagrant` from a folder without a `Vagrantfile`. Run the launcher from the generated package directory, not from the source repository root unless that is also the generated package.

```powershell
cd .\output\wc-12.1.2-foundation-build-0.1.0
.\Start-Foundation-Build.ps1
```

## VirtualBox cannot find `SATA Controller`

Regenerate the Admin package. The current Vagrantfile resizes the primary disk through Vagrant's disk support and does not assume a storage-controller name.

## `set: pipefail: invalid option name`

This indicates a Linux shell script likely reached the guest with Windows CRLF line endings. Regenerate the package; the generator normalizes generated `*.sh` files to Unix LF.

## Stage 01 cannot install `oracle-database-preinstall-19c`

AlmaLinux repositories may not contain Oracle's convenience preinstall package. The provisioning script falls back to explicit Oracle prerequisite packages and creates the required groups/users directly.

## Linux desktop UI should stay disabled

The VM is configured headless in VirtualBox, and stage 01 forces the guest to `multi-user.target` and masks common display managers. This preserves the selected CPU and memory sizing while avoiding unnecessary GUI services.

## Stage 03 cannot find a Windows media path inside Linux

Windows paths such as `C:\WindchillFoundationPOC\Media\Oracle` do not exist inside the Linux guest. The generated Vagrantfile validates the file on the Windows host and uploads the Oracle ZIP into `/tmp/windchill-foundation-oracle-media/` inside the guest.

## Oracle media upload fails with SCP permissions

The staging directory under `/tmp/windchill-foundation-oracle-media` is intentionally writable for the Vagrant file provisioner in this local POC. Regenerate the package if you are using an older build package.

## Profile requests Java 21 but the VM installs Java 11

Regenerate the Admin package after this fix. Stage 02 reads `profile.java.majorVersion` and installs `java-<major>-amazon-corretto-devel`, so a copied 13.1.2 profile with `java.majorVersion` set to `21` installs Amazon Corretto 21 instead of the 12.1.2 default of 11.


## Oracle installer fails with `Unable to find make utility in location: /usr/bin/make`

Oracle relinks database binaries during the software install, so `make` must be installed even when the Oracle preinstall package path succeeds. Stage 01 now installs and verifies `make` and `binutils` after the prerequisite package step so profile-specific runs do not depend on which prerequisite branch DNF took. Regenerate the Admin package, then clean or resume from a build where stage 01 has not been marked complete.

## Oracle installer fails with `cannot find /usr/lib64/libpthread_nonshared.a`

This file is provided by the Linux static glibc package. Stage 01 now installs `glibc-static` with the Oracle prerequisite packages before Oracle relinking starts. Clean or resume with a regenerated package so the prerequisite is present before stage 04 runs.

## Oracle installer fails with `libnsl.so.1: cannot open shared object file`

Oracle 19.3 includes a bundled Perl that expects the legacy `libnsl.so.1` soname on EL8-style guests. Stage 01 now verifies that `libnsl.so.1` is available after prerequisite installation, tries to install the package capability that provides it, and, for this local POC only, falls back to linking `libnsl.so.1` to the installed `libnsl.so.2` when the enabled AlmaLinux repositories do not provide the legacy soname directly. Also avoid changing `oracle.assumedDistribution` to `OL8` unless the profile has completed a full build; the checked-in `OEL7.8` compatibility override is the known-good default for the base Oracle 19.3 media used here.

## Oracle installer fails with `[INS-08101] supportedOSCheck`

Oracle Database 19.3 can fail supported OS checks on RHEL-compatible 8.x distributions. The POC sets `CV_ASSUME_DISTID` from the profile, defaulting to `OEL7.8`, and writes the same value into Oracle's `cvu_config` after extraction.

## Oracle installer reports success with warnings and exit code 6

Stage 04 treats Oracle installer exit code `6` as success-with-warnings because the software install can complete while optional prerequisite warnings are present. Other non-zero installer exit codes remain failures.

## DBCA reaches 100% then exits with code 6

DBCA can print `Database creation complete` and still return exit code `6` when post-creation recompilation reports warnings for optional components such as multimedia/spatial-related objects. Stage 06 now treats that as success-with-warnings only after it verifies the database opens in `READ WRITE` mode and saves PDB state. If the open verification fails, the stage still fails.

## Oracle install and DBCA are slow

The Oracle installer lays down the official 19.3 Enterprise Edition database home. This POC does not attempt to surgically remove database-home components because doing so risks Windchill compatibility. The database response disables Enterprise Manager, sample schemas, Database Vault, Oracle Label Security, and NetCA JavaVM listener registration, while preserving core RDBMS, networking, JVM, XML, and related libraries.

## NetCA says no valid IP address or `lsnrctl` is not found

Stage 01 maps the configured VM hostname to the guest's primary IPv4 address in `/etc/hosts`. Stage 05 runs NetCA and `lsnrctl` with explicit Oracle environment variables so tools are found even when the login shell environment is minimal.

## Stage 07 service startup fails after DBCA created the database

The service stage installs idempotent listener and database helper scripts as `oneshot` systemd units. If this fails, inspect:

```powershell
vagrant ssh -c 'sudo systemctl status oracle-listener oracle-database --no-pager'
vagrant ssh -c 'sudo journalctl -u oracle-listener -u oracle-database --no-pager -n 200'
```

The `ΓåÆ` characters sometimes shown in Windows Vagrant output are console rendering of systemd's symlink arrow and are not written into service files.
