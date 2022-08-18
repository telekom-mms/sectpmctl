# sectpmctl

We want to secure the Ubuntu 22.04 installation with LUKS and TPM2.

In this initial version no password is requested while booting that means that you have to supply a BIOS start password. It is planed to
release an updated shortly which implements a TPM + password option. In that case a BIOS start password is not neccessary. Without either
a BIOS start password or TPM + password, the device would boot up to the login screen and someone could try to read out the memory or
find a bug in the login screen to recover the LUKS key.

Either way you should also supply a BIOS admin password.

When installing the sectpmct bootloader, Microsoft UEFI keys are automatically uploaded to the Secure Boot database for your own safety.
In a future release an option will be included to suppress installing the Microsoft keys. Together with an BIOS admin password hardware
without an crucial UEFI OptionROM requirement like laptops with integrated graphics could benefit from doing so.

Dual booting Windows is not recommended and has never been tried with sectpmctl. The risk is that Windows will update the Secure Boot DBX
database which will prevent the successfull unlocking of the LUKS key. In such case you need the recovery key and need to redo the sectpmctl
installation.

## Build and install tpmsbsigntool

```
sudo apt install debhelper-compat gcc-multilib binutils-dev libssl-dev openssl pkg-config automake uuid-dev help2man gnu-efi tpm2-openssl

git clone https://github.com/T-Systems-MMS/tpmsbsigntool.git

cd tpmsbsigntool
gbp buildpackage --git-export-dir=../build_tpmsbsigntool -uc -us
cd ..

sudo dpkg -i build_tpmsbsigntool/tpmsbsigntool_0.9.4-1_amd64.deb
sudo apt install -f
```

## Build sectpmctl

```
sudo apt install debhelper efibootmgr efitools sbsigntool binutils mokutil dkms systemd udev util-linux gdisk openssl uuid-runtime tpm2-tools

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

The output should look like:

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

After installing sectpmctl, a key to sign kernels and kernel modules is stored inside the TPM in a serialized form in
'/var/lib/sectpmctl/keys/db.obj' for use with tpmsbsign. The key password is stored in '/var/lib/sectpmctl/keys/db.pwd'

There are two helper scripts which behave like sbsign and kmodsign in /usr/lib/sectpmctl/scripts:

- sbsign.sh
- kmodsign.sh

You need to supply a key and certificate which are stored in '/var/lib/sectpmctl/keys/':

- db.obj (key)
- db.cer (certificate)
- db.crt (certificate)

Depending on the tool you either need the CER or the CRT format as certificate.

#### TPM preparations

As sectpmctl will provision your TPM in a minimal way it is required to start the installation with a cleared TPM. That can be achived in three
ways:

- Clear the TPM (sometimes also called Security Chip) in the BIOS. Some BIOS require you press a key after a reboot to clear the TPM.
- Use Windows to disable TPM autoprovisioning and clear the TPM by using the PowerShell.
- Execute in Linux: "echo 5 | sudo tee /sys/class/tpm/tpm0/ppi/request" and reboot.

Be warned that when a TPM lockout password is set and you try to clear the TPM with software commands entering a wrong lockout password, there
will be a time penalty until you can try again. The above ways should allow to clear the TPM even when you entered a wrong lockout password.

The following command "mmstpm2 provisioning" will run successfully with a cleared TPM and the output should look like this:

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

This command will set a random lockout password which is stored in '/var/lib/sectpmctl/keys/lockout.pwd', set sane dictionary attack lockout time
penalty settings and create to TPM primary keys, one with dictionary attack lockout flag and one without (NODA).

The following DA lockout values are set:

- Wrong password retry count = 32 tries
- Recovery time = 10 minutes
- Lockout recovery time = 30 minutes

Unsealing the LUKS key (without TPM + password) while booting and signing of kernels and kernel modules is done by using the NODA primary key to
not break updates in case of a dictionary lockout situation. In the next release, when using TPM + password, specificly the unsealing will be done
with the DA key, while keep using the NODA key for signing kernels and kernel modules. 

### Installation

```
sudo bash

# Point of no return, you need to complete at least until the following reboot command
apt remove --allow-remove-essential "grub*" "shim*"
dpkg -i sectpmctl_1.0.0-1_amd64.deb
apt install -f

mmstpm2 provisioning

# TODO: hotfix for testing changes of sbsigntool
rm /usr/bin/kmodsign
echo '#!/bin/sh' > /usr/bin/kmodsign
echo 'KBUILD_SIGN_PIN="$(cat "/etc/mmstpm2/keys/db.pwd")" tpmkmodsign -P tpm2 -P default -Q "?provider=tpm2,tpm2.digest!=yes" sha256 "${2}" "${3}" "${4}" ${5}' >> /usr/bin/kmodsign
chown root:root /usr/bin/kmodsign
chmod 755 /usr/bin/kmodsign
rm /usr/bin/sbsign
echo '#!/bin/sh' > /usr/bin/sbsign
echo 'KBUILD_SIGN_PIN="$(cat "/etc/mmstpm2/keys/db.pwd")" tpmsbsign --provider tpm2 --provider default "$@"' >> /usr/bin/sbsign
chown root:root /usr/bin/sbsign
chmod 755 /usr/bin/sbsign

# TODO: Migrate /boot into root /, delete /boot partition, expand EFI partition

mmstpm2-boot --install

reboot

# Now your machine has its own set of Secure Boot keys, test it
mmstpm2-boot --test

# Install the LUKS TPM key
mmstpm2 install --setrecoverykey

# STORE THE PRINTED RECOVERY KEY NOW!!!
```

The 'mmstpm2 install' command will print out the recovery key. It is highly recommended to store this key in a safe location. Without this key you can loose
all your data when the TPM breaks or when accessing your hard disk in another machine. You are warned!

After a reboot the LUKS partition should decrypt automatically the the installation is complete.

## Updates

Remember that the recovery key is the only option when sectpmctl will not unlock anymore. See 'Recovery' for how to fix.

### Kernel or kernel module updates

Whenever a kernel update is installed or a new DKMS module, the corresponding hooks are called to automatically sign the kernel and or modules in a very similar
way like grub for example is updating.

### User space updates

No user space application except boot loaders should cause any trouble. Don't install any other boot loader as it will probably will set itself as first boot
entry. In such case you can enter the boot menu of your BIOS (often the F12 key or similar) and select sectpmctl again as boot device. You can do it also
permanently by using the efibootmgr command although it is a bit of a fiddle.

### BIOS Updates, eventually even with a new Secure Boot Database

BIOS updates should not be a problem as sectpmctl is not sealing the LUKS key to a specific BIOS version. On Lenovo Thinkpads it is even safe to install BIOS
updates which contain updates to the Secure Boot Database, most probably to supply an updated DBX list. It is safe to install such BIOS update as the new
database is provided but not installed automatically by the update.

### Custom kernels or kernel modules

Use the helper scripts for signing:

- /usr/lib/sectpmctl/scripts/sbsign.sh
- /usr/lib/sectpmctl/scripts/kmodsign.sh

## Recovery

In case of a changed Secure Boot database, sectpmctl will not unlock anymore. In that case you can simply repeat the sectpmctl installation. First clear the
Secure Boot database, the the TPM and finally repeat all steps from the installation. It is possible to do it more fine grained which will be documented in a later
release.

You can then ommit the '--setrecoverykey' option in the 'mmstpm2 install' command to keep your current recovery key.

## Disclaimer

Every Information or scripts in these repository are
written and collected with best intentions in mind. We do not
warrant that the information provided is complete, 
correct or that it is working on your plattform. 
We provide everything as is and try to fix bugs and
Security issues as soon as possible. 
We do not offerate to portate these to other Distributian as
Ubuntu.
Use on your own risk.

