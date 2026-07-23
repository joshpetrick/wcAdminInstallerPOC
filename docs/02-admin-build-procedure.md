# Admin build procedure

Generate the SQL Server Admin package:

```powershell
pwsh .\Generate-Package.ps1 -ProfilePath .\profiles\windchill-13.1.2-sqlserver.json -OutputDirectory .\output -Force
```

Extract `wc-13.1.2-foundation-build-sqlserver-0.1.0.zip`, then run:

```powershell
pwsh .\Start-Foundation-Build.ps1
```

On first run the launcher creates `secrets.json`. Populate `database.sqlServer.saPassword` with a complex SA password and rerun the same command. The build creates an AlmaLinux 9 VM, installs Java, installs SQL Server 2022 Developer from Microsoft repositories, validates SQL Server, sanitizes the VM, packages a `.box`, and publishes the artifact to the mock shared repository.

Use resume and cleanup commands printed by the launcher when failures occur. Do not claim a completed integration build unless Vagrant, VirtualBox, Microsoft repository access, and the full VM flow actually ran.


## Recovery and cleanup

Every failed `Start-Foundation-Build.ps1` run prints three follow-up commands: a log tail command, a resume command, and a cleanup command. Use `Resume-Foundation-Build.ps1` when the VM should continue after a transient issue, such as repository access. Use `Clean-Foundation-Build.ps1` when the build should be discarded and restarted from a clean VM.

```powershell
pwsh .\Resume-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
pwsh .\Clean-Foundation-Build.ps1 -BuildDirectory '<build-dir>'
```

`Clean-Foundation-Build.ps1` is preferred over manual deletion because it invokes Vagrant destruction before removing build files.
