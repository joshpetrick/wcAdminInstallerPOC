# Security and credentials

Generated packages include `secrets.example.json` only. They never generate or publish a populated `secrets.json`.

For the active SQL Server POC, `secrets.json` contains `database.sqlServer.saPassword`. The setup script uses `MSSQL_SA_PASSWORD`, not deprecated alternatives, and removes temporary setup secret material immediately after configuration. The password is not written to the manifest, validation report, or normal logs.

The current POC retains the configured SA password inside the packaged SQL Server instance so validation and future local development workflows can connect. This is a POC credential strategy. A future Developer Environment Builder should rotate or replace database credentials when it creates a developer-specific working VM.
