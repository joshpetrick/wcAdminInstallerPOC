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


## Stage 04 appears to stop after `SQL Server needs to be restarted`

Meaning: SQL Server accepted configuration changes, then the build waited during service restart or during the first local `sqlcmd` connection. Older packages did not print a heartbeat or timeout around that wait.

What to do:

1. Regenerate the package so stage 04 uses explicit setup/restart timeouts and prints service diagnostics if SQL Server does not accept local connections.
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
