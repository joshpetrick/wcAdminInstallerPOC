# Box usage and SSH

After the Admin build completes, the mock repository contains a reusable VirtualBox Vagrant `.box` named like:

```text
wc-13.1.2-foundation-alma9-sqlserver2022-virtualbox-0.1.0.box
```

To test it manually:

```powershell
vagrant box add wc-13.1.2-foundation-sqlserver .\wc-13.1.2-foundation-alma9-sqlserver2022-virtualbox-0.1.0.box
vagrant init wc-13.1.2-foundation-sqlserver
vagrant up --provider=virtualbox
vagrant ssh
```

Default SSH access uses Vagrant's standard `vagrant` user and generated private key. For PuTTY, run `vagrant ssh-config` and use the reported host, port, username, and private-key path. SQL Server listens inside the guest on `localhost,1433`; the POC does not require bridged networking or public SQL Server exposure.
