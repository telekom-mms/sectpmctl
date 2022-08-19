# sectpmctl

We want to secure the Ubuntu 22.04 installation with LUKS and TPM2. Please read this README carefully before installation.

In this initial version no password is requested while booting. That means that you should supply a BIOS start password. It is planed to
release an update shortly which implements a TPM + password option. In that case a BIOS start password is not neccessary. Without either
a BIOS start password or TPM + password, the device would boot up to the login screen and someone could try to read out the memory or
find a bug in the login screen to recover the LUKS key.

Either way you should also supply a BIOS admin password.

When installing the sectpmct bootloader, Microsoft UEFI keys are automatically uploaded to the Secure Boot database for your own safety.
In a future release an option will be included to suppress installing the Microsoft keys. Together with an BIOS admin password, hardware
without an crucial UEFI OptionROM requirement like laptops with integrated graphics could benefit from doing so.

Dual booting Windows is not recommended and has never been tested with sectpmctl. The risk is that Windows will update the Secure Boot DBX
database which will prevent the successfull unlocking of the LUKS key. In such case you need the recovery key and need to redo the sectpmctl
installation, see 'Recovery' for more information.

It is recommended to only have one LUKS slot in use, which is mostly slot 0. sectpmctl will additionally use slot 5 to store the TPM key.

## Build and install tpmsbsigntool

```
sudo apt install debhelper-compat gcc-multilib binutils-dev libssl-dev openssl pkg-config \
  automake uuid-dev help2man gnu-efi tpm2-openssl

git clone https://github.com/T-Systems-MMS/tpmsbsigntool.git

cd tpmsbsigntool
gbp buildpackage --git-export-dir=../build_tpmsbsigntool -uc -us
cd ..

sudo dpkg -i build_tpmsbsigntool/tpmsbsigntool_0.9.4-1_amd64.deb
sudo apt install -f
```

## Build sectpmctl

```
sudo apt install debhelper efibootmgr efitools sbsigntool binutils mokutil dkms systemd udev \
  util-linux gdisk openssl uuid-runtime tpm2-tools

git clone https://github.com/T-Systems-MMS/sectpmctl.git

cd sectpmctl
make package_build
cd ..
```

## Install sectpmctl

Warning: After removeing grub and shim there is no alternative then to complete the installation, otherwise your system will most probably
not boot anymore.

### Prerequisite

#### Secure Boot preparations

Your BIOS has to be in Secure Boot Setup Mode. That means that your BIOS need to have Secure Boot enabled and that all keys are cleared. You
can do so by entering your BIOS, enable Secure Boot and find inside the Secure Boot section the button to "Clear all keys".

I never came across a BIOS which does not offer a way to enter Secure Boot Setup Mode. If your BIOS supports listing all keys, after entering
the setup mode, the amount of keys of all databases should be listed as zero.

First check if your Secure Boot is enabled and cleared by executing this two commands:

```
mokutil --sb-state
efi-readvar
```

The output should look like this:

```
user@laptop:~$ mokutil --sb-state
SecureBoot disabled
Platform is in Setup Mode
user@laptop:~$ efi-readvar
Variable PK has no entries
Variable KEK has no entries
Variable db has no entries
Variable dbx has no entries
Variable MokList has no entries
user@laptop:~$
```

#### TPM preparations

As sectpmctl will provision your TPM in a minimal way it is required to start the installation with a cleared TPM. That can be achived in three
ways:

- Clear the TPM (sometimes also called Security Chip) in the BIOS if available. Some BIOS require you press a key after a reboot to clear the TPM.
- Use Windows to disable TPM autoprovisioning and clear the TPM by using PowerShell commands, followed by a reboot.
- Execute in Linux: "echo 5 | sudo tee /sys/class/tpm/tpm0/ppi/request" and reboot.

Be warned that if you put already some keys into the TPM, they will be lost by the clearing.

Be also warned that when a TPM lockout password is set and you try to clear the TPM with software commands entering a wrong lockout password, there
will be a time penalty until you can try again. The above three ways to clear should allow to clear the TPM even when you entered a wrong lockout password.

The following command "mmstpm2 provisioning" should run successfully with a cleared TPM and the output should look like this:

```
user@laptop:~# mmstpm2 provisioning
START PROVISIONING
## TPM CLEAR
## SET DICTIONARY LOCKOUT SETTINGS
## CREATE AND SET THE LOCKOUTAUTH VALUE
## CREATE PERSISTENT PRIMARY OWNER SRK AT 0x81000100
## CREATE PERSISTENT PRIMARY OWNER NODA SRK AT 0x81000101
user@laptop:~#
```

The provisioning will set a random lockout password which is stored in '/var/lib/sectpmctl/keys/lockout.pwd', set sane dictionary attack lockout time
penalty settings and create two TPM primary keys, one with dictionary attack lockout flag (DA) and one without (NODA).

The following DA lockout values are set:

- Wrong password retry count = 32 tries
- Recovery time = 10 minutes
- Lockout recovery time = 30 minutes

Unsealing the LUKS key (without TPM + password) while booting and signing of kernels and kernel modules is done by using the NODA primary key to
not break updates in case of a dictionary lockout situation. In the next release, when using TPM + password, specificly the unsealing will be done
with the DA key, while keep using the NODA key for signing kernels and kernel modules. 

All generated keys, passwords or serialized keys are stored in '/var/lib/sectpmctl/keys'.

### Installation

```
sudo bash

# Point of no return, you need to complete at least until the following reboot command
# Skip this three lines if already done (recovery situation)
apt remove --allow-remove-essential "grub*" "shim*"
dpkg -i sectpmctl_1.0.0-1_amd64.deb
apt install -f

mmstpm2 provisioning

# Skip migration of /boot if already done (recovery situation)
# TODO: Migrate /boot into root /, delete /boot partition, expand EFI partition

mmstpm2-boot --install

reboot

sudo bash

# Now your machine has its own set of Secure Boot keys, test it
mmstpm2-boot --test

# Install the LUKS TPM key. Enter your current LUKS key when asked.
mmstpm2 install --setrecoverykey

# STORE THE PRINTED RECOVERY KEY NOW!!!
```

The 'mmstpm2 install' command will print out the recovery key. It is highly recommended to store this key in a safe location. Without this key you can loose
all your data when the TPM breaks or when accessing your hard disk in another machine. You have been warned!

After a reboot the LUKS partition should decrypt automatically the the installation is complete.

You can then do some boot loader configuration by editing '/etc/sectpmctl/boot.conf'. Remember to update the boot loader afterwards by executing

```
sudo mmstpm2-boot --update
```

followed by a reboot. You can also use the bootctl command for basic tasks like listing the bootable kernels:

```
sudo bootctl list
```

## Updates

Remember that entering the recovery key while booting is the only option when sectpmctl will not unlock automatically anymore. See 'Recovery' for how to fix.

### Kernel or kernel module updates

Kernel or kernel module updates will not create any problems.  Whenever a kernel update is installed or a new DKMS module or update to it, the corresponding
hooks are called to automatically sign the kernel and/or kernel modules in a very similar way like DKMS and grub for example are doing updates.

### User space updates

No user space application except boot loaders should be able to cause any problem anytime. It is better to not install any other bootloader. The UEFI
specification allows for many boot loaders being installed in parallel. No other bootloader will overwrite sectpmctl but most probably change the boot order.
In such case you can enter the boot menu of your BIOS (often the F12 key or such) and select sectpmctl again as boot entry. You can do it also permanently by
using the efibootmgr command although it could be a bit of a fiddle.

### BIOS Updates, eventually even with an updated Secure Boot database

BIOS updates should be no problem as sectpmctl is not sealing the LUKS key to a specific BIOS version but only to a specific Secure Boot database and state and
enforces only use of it's own Secure Boot keys for booting while successfully unlocking the LUKS key. On Lenovo Thinkpads it is even safe to install BIOS
updates which contain updates to the Secure Boot Database (most probably to supply an updated DBX list). It is safe to install such BIOS update as well as the
new database is only provided but not applied automatically by the BIOS update.

### Custom kernels or kernel modules

After installing sectpmctl, a key to sign kernels and kernel modules is stored inside the TPM in a serialized form in
'/var/lib/sectpmctl/keys/db.obj' for use with tpmsbsigntool. The key password is stored in '/var/lib/sectpmctl/keys/db.pwd'

You normally don't need to use the db key manually. DKMS and kernel hooks are integrated and execute the sign commands automatically
for every kind of update. There are two helper scripts which behave like sbsign and kmodsign in '/usr/lib/sectpmctl/scripts' when you
need to sign things manually:

- sbsign.sh
- kmodsign.sh

You can even link the helper scripts over the sbsigntool executables by leveraging a debian config package if you need to do so,
for example to support maintainance of commercial anti virus applications or such.

You then need to supply a key and certificate which are stored in '/var/lib/sectpmctl/keys/':

- db.obj (key)
- db.cer (certificate)
- db.crt (certificate)

Depending on the tool you either need the CER or the CRT format as certificate.

Please read the helper scripts before manual using as they have specific needs for rewriting parameters. Hopefully the patches of tpmsbsigntool can be merged
upstream in sbsigntool in the future.

## Recovery

In case of a changed Secure Boot database, sectpmctl will not unlock anymore. In that case you can simply repeat the sectpmctl installation. First clear the
Secure Boot database, then clear the TPM and finally repeat all steps from the installation. It is possible to do it more fine grained which will be documented in a later
release.

You can then omit the '--setrecoverykey' option in the 'mmstpm2 install' command to keep your current recovery key.

## Disclaimer

Every information or code in these repository is written and collected with best intentions in mind. We do not
warrant that it is complete, correct or that it is working on your plattform. We provide everything as is and try to fix bugs and
security issues as soon as possible. Currently Ubuntu 22.04 is the only supported distribution. Use at your own risk.

