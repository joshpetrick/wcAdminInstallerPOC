# Troubleshooting

## SQL Server repository access fails

The SQL Server provider checks Microsoft package endpoints before installing packages. DNS, HTTPS inspection, proxy requirements, repository outages, package unavailability, or certificate problems must be fixed before stage 03 can continue.

## SQL Server version is below CU10

SQL Server 2022 support on RHEL 9 begins with CU10. The provider queries `SERVERPROPERTY('ProductVersion')` and fails if the effective product version is below `16.0.4100.1`.

## SA password is rejected

Populate `database.sqlServer.saPassword` in `secrets.json`. It must not be empty or a placeholder and must satisfy SQL Server complexity rules. The password is passed to setup through `MSSQL_SA_PASSWORD` in a protected temporary environment file that is deleted after setup.

## Oracle media errors

The active SQL Server package should not check for Oracle media. If a generated SQL Server package asks for `LINUX.X64_193000_db_home.zip`, regenerate from `profiles/windchill-13.1.2-sqlserver.json`.
