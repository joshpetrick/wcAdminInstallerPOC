# Troubleshooting

Use the log command printed by `Start-Foundation-Build.ps1` first:

```powershell
Get-Content -Path '<build-dir>\build.log' -Tail 200
```

After applying a fix, use the printed resume command unless the fix requires a fresh VM. Use cleanup when the VM is in an unknown state.

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```


## How to access detailed guest logs

The Windows `build.log` captures Vagrant output, but each Linux stage also writes a detailed guest log under `/var/lib/windchill-foundation/logs`. From the generated package or build directory, use:

```powershell
Get-Content -Path '<build-dir>\build.log' -Tail 200
cd '<build-dir>'
vagrant ssh
sudo ls -lh /var/lib/windchill-foundation/logs
sudo tail -n 200 /var/lib/windchill-foundation/logs/04-configure-database.log
sudo tail -n 200 /var/lib/windchill-foundation/logs/05-validate-database.log
sudo systemctl status mssql-server --no-pager
sudo journalctl -u mssql-server -n 200 --no-pager
```

If SSH cannot connect, the VM may still be booting or Vagrant may have stopped the run after a provisioning error. Re-run `vagrant ssh` from the build directory after the prompt returns.

## `VBoxManage` was not found

Meaning: Vagrant is installed, but the VirtualBox CLI is not installed or is not discoverable. Vagrant and VirtualBox are separate products.

What to do:

1. Install Oracle VirtualBox 7.x.
2. Close and reopen PowerShell.
3. Verify one of these commands works:

```powershell
VBoxManage --version
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' --version
```

If the second command works but the first does not, add the VirtualBox install directory to the Windows `PATH`, or rely on the updated prerequisite checker which looks in the default install location.

## SQL Server SA password is rejected

Meaning: SQL Server rejected the configured `database.sqlServer.saPassword` during unattended setup, or the launcher rejected it before setup.

What to do:

1. Open `secrets.json` in the extracted package directory.
2. Set `database.sqlServer.saPassword` to a value with at least 12 characters.
3. Include uppercase, lowercase, numeric, and symbol characters.
4. Avoid dictionary words, `sa`, company names, and placeholders.
5. Rerun the start or resume command.

Example shape, not a password recommendation:

```json
{
  "database": {
    "provider": "SQLSERVER",
    "sqlServer": {
      "saPassword": "<12+ chars with upper/lower/number/symbol>"
    }
  }
}
```

The password is passed to SQL Server setup through `MSSQL_SA_PASSWORD` in a protected temporary environment file and is removed after setup. Do not paste real passwords into support tickets or logs.

## SQL Server repository access fails

Meaning: the guest VM cannot reach Microsoft package endpoints before stage 03 installs SQL Server.

What to do:

1. Confirm the host network allows HTTPS access.
2. If your organization requires a proxy, configure Vagrant/guest proxy handling before retrying.
3. Check DNS and TLS inspection policies.
4. Retry with:

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

## SQL Server package is unavailable or `unixODBC` conflicts

Meaning: Microsoft repository metadata was reachable, but DNF could not find `mssql-server`/`mssql-tools18`, or package resolution found a conflict such as `unixODBC-devel` requiring Microsoft's `unixODBC = 2.3.11` while AlmaLinux AppStream already selected a newer `unixODBC`.

What to do:

1. Regenerate the package so stage 03 uses the updated SQL tools install command with `--allowerasing`.
2. Resume the same build if stage 03 failed before SQL Server setup started:

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

3. Confirm the active profile uses `repositoryPlatform: rhel` and `repositoryMajorVersion: 9`.
4. If using `packageVersionPolicy: PINNED`, verify `pinnedPackageVersion` exactly matches an available package version.
5. If DNF still cannot resolve packages, clean the build and retry after repository availability is restored.


## `xargs: {}: No such file or directory` after SQL tools install

Meaning: SQL Server tools installed, but the old validation command attempted to launch `sqlcmd` through an unsafe `xargs` pattern.

What to do:

1. Regenerate the package so stage 03 resolves `sqlcmd` into a variable and executes that path directly.
2. Resume the build because SQL Server setup has not started yet:

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

## SQL Server version is below CU10

Meaning: SQL Server installed, but `SERVERPROPERTY('ProductVersion')` is lower than the profile minimum `16.0.4100.1`.

What to do:

1. Keep `packageVersionPolicy: LATEST_AVAILABLE` for the POC unless a pinned version has been approved.
2. If pinned, update the pinned SQL Server package to CU10 or later.
3. Clean and rebuild so the VM installs the corrected package.


## Stage 04 reports `Port '1433' is already in use` or appears to stop after restart messages

Meaning: SQL Server setup already started on the default port, so setting `network.tcpport` to `1433` can report that the port is in use. The updated configuration script treats an already-listening default 1433 as acceptable and skips the redundant port set. If the build appears stopped after restart messages, it is waiting during service restart or the first local `sqlcmd` connection.

What to do:

1. Regenerate the package so stage 04 skips redundant port setting, uses explicit setup/restart timeouts, and prints service diagnostics if SQL Server does not accept local connections.
2. Resume the build if SQL Server setup was still healthy:

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

3. If the stage fails again, inspect the service from the build directory:

```powershell
vagrant ssh
sudo systemctl status mssql-server --no-pager
sudo journalctl -u mssql-server -n 200 --no-pager
```

## SQL Server service does not start or port 1433 is not listening

Meaning: `mssql-server` did not become healthy after setup/configuration.

What to do from the build directory:

```powershell
vagrant ssh
sudo systemctl status mssql-server --no-pager
sudo journalctl -u mssql-server -n 200 --no-pager
sudo ss -ltnp | grep 1433
```

Correct the root cause, then resume if the VM is still healthy. If SQL Server setup partially completed with bad configuration or credentials, clean and rebuild.

## Oracle media errors

The active SQL Server package should not check for Oracle media. If a generated SQL Server package asks for `LINUX.X64_193000_db_home.zip`, regenerate from `profiles/windchill-13.1.2-sqlserver.json` and confirm the generated package name contains `sqlserver`.

## Stage 05 fails with `SQL Server Agent expected true found <empty>`

Meaning: SQL Server is running, but validation could not read the Linux SQL Server Agent setting from `mssql-conf`. Some package versions print `mssql-conf get sqlagent.enabled` differently than expected, while the effective setting is stored under `[sqlagent]` in `/var/opt/mssql/mssql.conf`.

What to do from the build directory:

```powershell
vagrant ssh
sudo /opt/mssql/bin/mssql-conf get sqlagent.enabled
sudo sed -n '/^\[sqlagent\]/,/^\[/p' /var/opt/mssql/mssql.conf
sudo systemctl status mssql-server --no-pager
```

If `/var/opt/mssql/mssql.conf` shows `enabled = true`, regenerate the Admin package from this repository and resume the build so stage 05 uses the fallback parser:

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

If the value is missing or false, rerun stage 04 by cleaning and rebuilding, or set it manually for diagnosis only:

```powershell
vagrant ssh
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
sudo systemctl restart mssql-server
```

Then resume the generated package. The production POC path should configure this automatically; manual changes are only for investigating a partially built VM.

## What stage 05 (`05-validate-database`) checks

Stage 05 is not creating a Windchill database. It is a gate that proves the foundation SQL Server instance is usable before the VM is sanitized and boxed. The stage checks that:

- `mssql-server`, `sqlservr`, and `sqlcmd` are installed.
- `mssql-server` is enabled, active, and listening on the configured local port.
- SQL authentication works with the protected `saPassword` from `secrets.json`.
- SQL Server reports version 16.x and meets the configured CU10-or-later minimum.
- Developer Edition, contained database authentication, SQL Server Agent/Agent XPs, and max memory match the profile.
- A temporary `FoundationValidation` database can be created and removed.

A `vagrant up failed` message at this point means Vagrant is reporting that the Linux validation script returned a non-zero exit code. Use the `Log command` shown by `Start-Foundation-Build.ps1` first, then use `vagrant ssh` from the build directory for deeper inspection.

## Stage 05 reports `No setting for the given option` for `sqlagent.enabled`

Meaning: SQL Server is active, but the prior package did not persist the `[sqlagent] enabled = true` entry in `/var/opt/mssql/mssql.conf`, or the `mssql-conf get` output was parsed as a setting value. SQL Server Agent on modern Linux SQL Server is enabled with `mssql-conf set sqlagent.enabled true` and a service restart; SSMS visibility also depends on the SQL `Agent XPs` option.

What to do:

1. Regenerate the Admin package so stage 04 persists `[sqlagent] enabled = true`, enables `Agent XPs`, and stage 05 ignores `No setting...` as a missing value instead of treating it as the value.
2. For an existing failed VM, inspect the state:

```powershell
vagrant ssh
sudo /opt/mssql/bin/mssql-conf get sqlagent.enabled
sudo sed -n '/^\[sqlagent\]/,/^\[/p' /var/opt/mssql/mssql.conf
/opt/mssql-tools18/bin/sqlcmd -S localhost,1433 -U sa -C -Q "SELECT value_in_use FROM sys.configurations WHERE name = 'Agent XPs';"
```

3. If you are only diagnosing the existing VM, you can apply the expected setting manually and then resume:

```powershell
vagrant ssh
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
sudo systemctl restart mssql-server
exit
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

For the normal POC path, prefer a clean rebuild with the regenerated package so the final `.box` is produced only from scripted configuration.

## Failure after stage 08 before packaging: guest not ready for inline reboot

Meaning: provisioning completed through SQL Server validation and sanitization, but the old Vagrantfile attempted an additional inline guest reboot as a shell provisioner. After sanitization, guest identity cleanup can make that inline guest-operation path fragile even though the VM itself is healthy.

What changed: reboot persistence is now orchestrated from `Start-Foundation-Build.ps1` with `vagrant reload --force`, followed by an explicit SSH call to `scripts/06-reboot-validation.sh`. This keeps the reboot validation requirement but avoids the fragile inline reboot provisioner.

What to do:

1. Regenerate the Admin package from the updated repository.
2. Prefer a clean rebuild so the generated Vagrantfile no longer contains `inline: 'reboot'`.
3. If investigating the existing VM, run these commands from its build directory:

```powershell
vagrant status
vagrant reload --force
vagrant ssh -c 'sudo /vagrant/scripts/06-reboot-validation.sh'
```

If those commands pass, the SQL Server foundation itself is healthy; the failure was in the old host-side reboot orchestration.
