# sectpmctl

We want to secure the Ubuntu 22.04 installation with LUKS and TPM2. Please read this README carefully before installation.

We also assume a normal installation of Ubuntu 22.04 desktop with erasing the disk and using LVM and encryption. Otherwise an installation
is possible but currently undocumented. A preseed installation is also possible but currently undocumented as well.

If you are not using the TPM + password option you should supply a BIOS start password. Without either a BIOS start password or
TPM + password, the device would boot up to the login screen and someone could try to read out the memory or find a bug in the login
screen to recover the LUKS key.

Either way you should also supply a BIOS admin password.

When installing the sectpmct bootloader, Microsoft UEFI keys are automatically uploaded to the Secure Boot database for your own safety.
In a future release an option will be included to suppress installing the Microsoft keys. Together with an BIOS admin password, hardware
without an crucial UEFI OptionROM requirement like laptops with integrated graphics would benefit from doing so.

Dual booting Windows is not recommended and has never been tested with sectpmctl. The risk is that Windows will update the Secure Boot DBX
database which will prevent the successfull unlocking of the LUKS key. In such case you need the recovery key and need to redo the sectpmctl
installation, see 'Recovery' for more information.

It is recommended to only have one LUKS slot in use, which is mostly slot 0. sectpmctl will additionally use slot 5 to store the TPM key.

You can easily test the installation with virt-manager on a Ubuntu 22.04 host and a Ubuntu 22.04 guest. When creating a new VM you need to
configure the VM before it starts automatically. In the overview select 'OVMF_CODE_4M.secboot.fd' as firmware and then add a new 'TPM
emulated TIS 2.0'device. After installation of Ubuntu you can start installing sectpmctl.

## Features

* TPM2 backed FDE
* Provisions the TPM with sane settings in a minimal way
* Encrypts communication to and from the TPM
* Uses the trust on first use (TOFU) principle. The bonding happens at TPM provisioning time
* Passwordless or TPM + password option
  + Passwordless option is not influenced by DA lockout
  + TPM + Password option is influenced by DA lockout
  + Secure Boot signing is not influenced by DA lockout
* Zero TPM administrative overhead by managing Secure Boot instead of the TPM
  + Secure Boot is more easy to manage
  + FDE key is only bound to the Secure Boot state, not to userspace
  + Immune to operating system upgrades
  + No postprocessing other then the kernel and initrd signing required
  + Interrupted update of new kernels should still keep old kernels bootable
  + Additional installation of other bootloaders will not overwrite sectpmctl, they are placed alongside
* Can be integrated in a nealy fullly automated preseed installation
  + The only upfront action is to clear TPM and Secure Boot
* The secureboot datase is completly rebuild with own keys and Microsoft keys for safety reasons
* Uses and integrates systemd-stub and systemd-boot as bootloader, does not invent a new one
* Implemented in bash

## Build and install tpmsbsigntool

```
sudo apt install git git-buildpackage debhelper-compat gcc-multilib binutils-dev libssl-dev openssl pkg-config \
  automake uuid-dev help2man gnu-efi tpm2-openssl

git clone https://github.com/T-Systems-MMS/tpmsbsigntool.git

cd tpmsbsigntool
gbp buildpackage --git-export-dir=../build_tpmsbsigntool -uc -us
cd ..

sudo dpkg -i build_tpmsbsigntool/tpmsbsigntool_0.9.4-1_amd64.deb
sudo apt install -f
```

## Build sectpmctl

You can ignore the 'debsign: gpg error occurred!  Aborting....' error when building yourself.

```
sudo apt install debhelper efibootmgr efitools sbsigntool binutils mokutil dkms systemd udev \
  util-linux gdisk openssl uuid-runtime tpm2-tools fdisk

git clone https://github.com/T-Systems-MMS/sectpmctl.git

cd sectpmctl
make package_build
cd ..
```

## Install sectpmctl

Warning: After removing grub and shim there is no alternative then to complete the installation, otherwise your system will most probably
not boot anymore.

### Prerequisite

#### Secure Boot preparations

Your BIOS has to be in Secure Boot Setup Mode. That means that your BIOS need to have Secure Boot enabled and that all keys are cleared. You
can do so by entering your BIOS, enable Secure Boot and find inside the Secure Boot section the button to "Clear all keys".

We never came across a BIOS which does not offer a way to enter Secure Boot Setup Mode. If your BIOS supports listing all keys, after entering
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

- Clear the TPM (sometimes also called Security Chip) in the BIOS if available. Some BIOS types require you press a key after a reboot to clear the TPM.
- Use Windows to disable TPM autoprovisioning and clear the TPM by using PowerShell commands, followed by a reboot.
- Execute in Linux: "echo 5 | sudo tee /sys/class/tpm/tpm0/ppi/request" and reboot.

Be warned that if you put already some keys into the TPM, they will be lost by the clearing.

Be also warned that when a TPM lockout password is set and you try to clear the TPM with software commands entering a wrong lockout password, there
will be a time penalty until you can try again. The above three ways to clear should allow to clear the TPM even when you entered a wrong lockout password.

To check if the TPM is in a good state enter:

```
sudo tpm2_getcap properties-variable
```

The output should look like this:

```
user@laptop:~$ sudo tpm2_getcap properties-variable
...
  lockoutAuthSet:            0
...
  inLockout:                 0
...
user@laptop:~$
```

The command which will be executed later while installing, "sectpmctl tpm provisioning", should run successfully with a cleared TPM and the output
should look like this:

```
user@laptop:~$ sudo sectpmctl tpm provisioning
START PROVISIONING
## TPM CLEAR
## SET DICTIONARY LOCKOUT SETTINGS
## CREATE AND SET THE LOCKOUTAUTH VALUE
## CREATE PERSISTENT PRIMARY OWNER SRK AT 0x81000100
## CREATE PERSISTENT PRIMARY OWNER NODA SRK AT 0x81000101
user@laptop:~$
```

The provisioning will set a random lockout password which is stored in '/var/lib/sectpmctl/keys/lockout.pwd', set sane dictionary attack lockout time
penalty settings and create two TPM primary keys, one with the dictionary attack lockout flag (DA) and one without (NODA).

The following DA lockout values are set:

- Wrong password retry count = 32 tries
- Recovery time = 10 minutes
- Lockout recovery time = 30 minutes

Unsealing the LUKS key while booting (currently without TPM + password) and signing of kernels and kernel modules is done by using the NODA primary key to
not break updates in case of a dictionary lockout situation. In the next release, when using the TPM + password option, specificly the unsealing will be
done with the DA key, while keep using the NODA key for signing kernels and kernel modules. 

All generated keys, passwords or serialized keys are stored in '/var/lib/sectpmctl/keys'.

### Installation

```
# 1. Point of no return, you need to complete at least until the following reboot command
sudo apt remove --allow-remove-essential "grub*" "shim*"
sudo dpkg -i sectpmctl_1.1.0-1_amd64.deb
sudo apt install -f


# 2. TPM Provisioning
sudo sectpmctl tpm provisioning


# 3. Cleanup leftovers from grub, shim and windows stuff from efibootmgr
entryId=""
entryId=$(efibootmgr -v | grep -i "Windows Boot Manager" | sed -e 's/^Boot\([0-9]\+\)\(.*\)$/\1/')
if [[ "x${entryId}" != "x" ]]; then
  sudo efibootmgr -q -b "${entryId}" -B
fi
entryId=""
entryId=$(efibootmgr -v | grep -i "ubuntu" | sed -e 's/^Boot\([0-9]\+\)\(.*\)$/\1/')
if [[ "x${entryId}" != "x" ]]; then
  sudo efibootmgr -q -b "${entryId}" -B
fi
while [[ $(efibootmgr | grep -c -m 1 "SECTPMCTL Bootloader") -gt 0 ]]
do
  entryId=$(efibootmgr -v | grep -m 1 -i "SECTPMCTL Bootloader" | sed -e 's/^Boot\([0-9]\+\)\(.*\)$/\1/')
  sudo efibootmgr -q -b "${entryId}" -B
done


# 4. Now migrate boot partition to root, the following partition table is assumed, change all references
# according to your device and partition names and numbers:

# $DISK          -> /dev/vda (the disk)
# $EFIPARTITION  -> /dev/vda1 (EFI-System, vfat, partition type 1)
# $BOOTPARTITION -> /dev/vda2 (boot partition, ext4)
# $LUKSPARTITION -> /dev/vda3 (encrypted root partition)

sudo umount /boot/efi
sudo umount /boot
sudo mkdir /oldboot
sudo mount /dev/$BOOTPARTITION /oldboot
sudo cp -rp /oldboot/* /boot/
sudo umount /oldboot
sudo rmdir /oldboot

sudo dd if=/dev/zero of=/dev/$EFIPARTITION bs=1M
sudo dd if=/dev/zero of=/dev/$BOOTPARTITION bs=1M
sudo fdisk /dev/$DISK
  # delete partition $BOOTPARTITION (e.g. vda2)
  # delete partition $EFIPARTITION (e.g. vda1)
  # create new parttion $EFIPARTITION (e.g. vda1)
    # startsector same as startsector of old $EFIPARTITION
    # lastsector same as lastsector of old $BOOTPARTITION
    # remove signature: YES
  # change type of partition $EFIPARTITION (e.g. vda1)
    # type nr: 1 (EFI-System)
  # write and quit
sudo mkfs.vfat /dev/$EFIPARTITION
sudo blkid -s UUID -o value /dev/$EFIPARTITION
  # copy the UUID of /dev/$EFIPARTITION, something like: 00A5-1112
sudo vi /etc/fstab
  # remove /boot entry from fstab
  # change the old UUID of /boot/efi to the copied new UUID of the blkid output
sudo mount /boot/efi


# 5. Install the bootloader
sudo sectpmctl boot install

# After this reboot your current LUKS password is still required
sudo reboot


# 6. Install the LUKS TPM implementation
# Now your machine has its own set of Secure Boot keys, test it
sudo sectpmctl boot test

# Install the LUKS TPM key. Enter your current LUKS key when asked.
sudo sectpmctl tpm install --setrecoverykey --password "mypassword"

# STORE THE PRINTED RECOVERY KEY NOW!!!
```

The 'sectpmctl tpm install' command will print out the recovery key. It is highly recommended to store this key in a safe location. Without this key you can loose
all your data when the TPM breaks or when accessing your hard disk in another machine. You have been warned!

After a reboot, the LUKS partition should decrypt automatically and the installation is complete.

You can then do some bootloader configuration by editing '/etc/sectpmctl/boot.conf'. Remember to update the bootloader afterwards by executing:

```
sudo sectpmctl boot update
```

followed by a reboot. You can also use the bootctl command for basic tasks like listing the bootable kernels:

```
sudo bootctl list
```

If the password option has been used, the current password can be changed at runtime with:

```
sudo sectpmctl key changepassword --handle 0x81000102 --oldpassword "myoldpwd" --password "mynewpwd"
```

If the current password is lost, a new password can be set with the recovery key by installing again:

```
sectpmctl tpm install --setrecoverykey --password "mynewpassword"
```
      
## Updates

Remember that entering the recovery key while booting is the only option when sectpmctl will not unlock automatically anymore. See 'Recovery' for how to fix.

### Kernel or kernel module updates

Kernel or kernel module updates will not create any problems.  Whenever a kernel update is installed or a new DKMS module or update to such, the corresponding
hooks are called to automatically sign the kernel and/or kernel modules in a very similar way like DKMS and grub for example are doing updates.

### Userspace updates

No userspace application except bootloaders should be able to cause any problem anytime. It is better to not install any other bootloader. The UEFI
specification allows for many bootloaders being installed in parallel. No other bootloader will overwrite sectpmctl but most probably change the boot order.
In such case you can enter the bootmenu of your BIOS (often the F12 key or such) and select sectpmctl again as boot entry. You can do it also permanently by
using the efibootmgr command although it could be a bit of a fiddle.

### BIOS Updates, eventually even with an Secure Boot database update

BIOS updates should be no problem as sectpmctl is not sealing the LUKS key to a specific BIOS version, but only to a specific Secure Boot database and state
while enforcing the use of it's own Secure Boot db keys for successfully unlocking the LUKS key while booting. On some BIOS types it is even safe to install BIOS
updates which contain updates to the Secure Boot Database (most probably to supply an updated DBX list). It is safe to install such BIOS update as wells as the
new database is only provided but not applied automatically by the BIOS update.

### Custom kernels or kernel modules

After installing sectpmctl, a key (db) to sign kernels and kernel modules is stored in the TPM in a serialized form in
'/var/lib/sectpmctl/keys/db.obj' for use with tpmsbsigntool. The key password is stored in '/var/lib/sectpmctl/keys/db.pwd'

You normally don't need to use the db key manually. DKMS and kernel hooks are integrated and execute the sign commands automatically
for every kind of Ubuntu upgrades. There are two helper scripts which behave like sbsign and kmodsign in '/usr/lib/sectpmctl/scripts' when you
need to sign things manually:

- sbsign.sh
- kmodsign.sh

You can even link the helper scripts over the sbsigntool executables by leveraging a debian config package if you need to do so,
for example to support maintainance of commercial antivirus applications or such.

You then need to supply a key the certificate which are stored in '/var/lib/sectpmctl/keys/':

- db.obj (key)
- db.cer (certificate)
- db.crt (certificate)

Depending on the tool you either need the CER or the CRT file as certificate.

Please read the helper scripts before manual using them as they have specific needs for rewriting parameters. Hopefully the patches of tpmsbsigntool can be merged
upstream in sbsigntool in the future.

## Recovery

In case of a changed Secure Boot database, sectpmctl will not unlock anymore. In that case you can simply repeat the sectpmctl installation. First clear the
Secure Boot database, then clear the TPM and finally repeat all steps exept 1. and 4. from the installation. It is possible to do it more fine grained which will
be documented in a later release.

You could then omit the '--setrecoverykey' option in the 'sectpmctl tpm install' command to keep your current recovery key.

## Disclaimer

Every information or code in these repository is written and collected with best intentions in mind. We do not
warrant that it is complete, correct or that it is working on your plattform. We provide everything as is and try to fix bugs and
security issues as soon as possible. Currently Ubuntu 22.04 is the only supported distribution. Use at your own risk.

