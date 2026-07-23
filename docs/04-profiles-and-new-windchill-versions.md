# Profiles and new Windchill versions

The active profile is `profiles/windchill-13.1.2-sqlserver.json`. It targets Windchill `13.1.2.0`, AlmaLinux 9.6 or later, Java 21, and the `SQLSERVER` database provider.

Database configuration is provider-neutral at the top level:

```json
"database": {
  "provider": "SQLSERVER",
  "profileId": "sqlserver-2022-developer-linux",
  "sqlServer": { }
}
```

Use `packageVersionPolicy: LATEST_AVAILABLE` for the POC so Microsoft repositories provide the current SQL Server 2022 CU. A future approved profile can set `packageVersionPolicy: PINNED` and provide `pinnedPackageVersion` for reproducibility. Microsoft SQL Server release history documents that SQL Server 2022 on RHEL 9 requires CU10 or later, so `minimumProductVersion` must remain at least `16.0.4100.1`.

Oracle may be reintroduced through `database.provider: ORACLE` only after a future profile supplies approved Oracle media, OPatch, and RU inputs. The current generator recognizes Oracle but rejects it as `DISABLED_FOR_CURRENT_POC`.
