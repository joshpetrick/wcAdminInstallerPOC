# Concepts and architecture

The Admin Foundation Image Builder is a profile-driven generator. A profile selects the hypervisor, operating system, Java version, and database provider. The generated package is self-contained and can run without Git.

```text
Admin foundation profile
        ↓
Database provider selection
        ↓
SQLSERVER provider
        ↓
Generated Admin build package
        ↓
Vagrant + VirtualBox
        ↓
AlmaLinux 9 + Java + SQL Server 2022 Developer
        ↓
Validation and sanitization
        ↓
Reusable VirtualBox .box
        ↓
Mock shared repository
```

The active provider is `SQLSERVER`. `ORACLE` remains documented as a future disabled provider because it requires approved Oracle 19c RU and organization-provided patch media. Provider scripts live under `package-template/scripts/database-providers/<provider>/` and are called by generic stage dispatch scripts.
