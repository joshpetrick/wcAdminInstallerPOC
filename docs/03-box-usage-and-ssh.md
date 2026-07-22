# 03 - Box usage and SSH

This chapter explains what to do after `Start-Foundation-Build.ps1` creates the `.box` file.

## Where the box is created

The current launcher writes the box into the timestamped build folder:

```text
C:\WindchillFoundationPOC\Builds\<build-folder>\wc-12.1.2-foundation-virtualbox-0.1.0.box
```

For a future `13.1.2.0` profile, the generated box name follows the profile version:

```text
wc-13.1.2-foundation-virtualbox-0.1.0.box
```

## Add the box to local Vagrant

Choose a local Vagrant box name. The name is an alias on your machine:

```powershell
vagrant box add wc-12.1.2-foundation 'C:\WindchillFoundationPOC\Builds\<build-folder>\wc-12.1.2-foundation-virtualbox-0.1.0.box' --force
```

Confirm it is registered:

```powershell
vagrant box list
```

## Create a consumer test VM

Create a clean folder for testing the completed foundation box:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\WindchillFoundationPOC\Consumers\wc121-smoke'
cd 'C:\WindchillFoundationPOC\Consumers\wc121-smoke'
```

Create a minimal `Vagrantfile`:

```powershell
@'
Vagrant.configure("2") do |config|
  config.vm.box = "wc-12.1.2-foundation"
  config.vm.hostname = "wc121-foundation-consumer"
  config.vm.provider "virtualbox" do |vb|
    vb.name = "wc121-foundation-consumer"
    vb.cpus = 6
    vb.memory = 12288
    vb.gui = false
  end
end
'@ | Set-Content -Encoding ascii -Path .\Vagrantfile
```

Start the VM:

```powershell
vagrant up --provider=virtualbox
```

## SSH with Vagrant

From the folder containing the consumer `Vagrantfile`:

```powershell
vagrant ssh
```

Run one command without opening an interactive shell:

```powershell
vagrant ssh -c 'hostname; java -version; sudo systemctl is-active oracle-listener oracle-database'
```

Switch to the Oracle OS user:

```bash
sudo su - oracle
```

Connect locally as SYSDBA:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_SID=WCDEV
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysdba
```

Useful SQL checks:

```sql
select status from v$instance;
show pdbs;
exit
```

## SSH details for PuTTY

Vagrant manages SSH keys for each VM. To see the active SSH settings, run this from the folder containing the `Vagrantfile`:

```powershell
vagrant ssh-config
```

Typical output includes:

```text
Host default
  HostName 127.0.0.1
  User vagrant
  Port 2222
  IdentityFile C:/.../.vagrant/machines/default/virtualbox/private_key
```

Configure PuTTY with those values:

| PuTTY field | Value |
| --- | --- |
| Host Name | `127.0.0.1` |
| Port | The `Port` from `vagrant ssh-config`, often `2222` but not guaranteed. |
| Connection type | SSH |
| User name | `vagrant` |
| Private key | The `IdentityFile` path from `vagrant ssh-config`. |

If your PuTTY version does not accept the OpenSSH private key directly, open PuTTYgen, load the `IdentityFile`, save a `.ppk`, then point PuTTY to that `.ppk` under **Connection > SSH > Auth > Credentials**.

## Credentials and users

| Account | Purpose | How to access |
| --- | --- | --- |
| `vagrant` | Default SSH user managed by Vagrant. | `vagrant ssh`, or PuTTY using the Vagrant private key. |
| `root` | Administrative Linux account. | Use passwordless `sudo` from `vagrant`; do not rely on direct root SSH. |
| `oracle` | Oracle software owner. | `sudo su - oracle` from the `vagrant` user. |
| `SYS`, `SYSTEM`, `PDBADMIN` | Oracle database accounts. | Passwords come from `secrets.json` used during the build. |

## Stop or destroy a consumer VM

Halt without deleting disks:

```powershell
vagrant halt
```

Destroy the VM when done:

```powershell
vagrant destroy -f
```

Destroying a consumer VM does not remove the registered Vagrant box. To remove the local box alias:

```powershell
vagrant box remove wc-12.1.2-foundation --force
```
