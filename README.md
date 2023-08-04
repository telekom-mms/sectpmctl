# sectpmctl 1.1.4-1

## Notes

### Ubuntu >= 22.10

Please choose the branch ubuntu_22_10_support for Ubuntu >= 22.10. The branch is stable and tested up to Ubuntu 23.04 but is missing an upgrade
path from the older version 22.04. The reason are changes to the TPM2 PCR allocations which are incompatible. The recommondation is to perform
a clean installation of Ubuntu >= 22.10 and then install sectpmctl from the ubuntu_22_10_support branch, without doing a dist-upgrade.
Alternatively you can wait until it is completely supported by sectpmctl. A solution to do successfull dist-upgrades is to have an automated
upgrade boot, in which the LUKS key is resealed inside the initrd to the new set of PCR values. Such solution is expected to be provided for
the next LTS release 24.04.

### FaulTPM attack

Support for the key derivation function (KDF) argon2 is currently in work. It will be integrated into the TPM + password option.

## Introduction

**Warning: It is highly recommended to install sectpmctl on a fresh Ubuntu installation as you could run into problems when the tpm2-tools
or efitools can't be executed successfully on your device. Create at least a backup of your data before installation. If you already
installed DKMS modules, it is probably necessary to rebuild them after installing sectpmctl to have them signed.**

We want to secure the Ubuntu 22.04 installation with LUKS and TPM2. Please read this README carefully before installation.

We assume a normal installation of Ubuntu 22.04 desktop by erasing the disk and using LVM and encryption. Don't select to create a recovery
key, only the LUKS password. A preseed installation is possible but currently undocumented. Other Linux distributions can probably be supported
in future releases.

If you are not using the TPM + password option you should supply a BIOS start password. Without either a BIOS start password or
TPM + password, the device would boot up to the login screen and someone could try to read out the memory or find a bug in the login
screen to recover the LUKS key.

Either way, you should also supply a BIOS admin password.

Dual booting Windows is not recommended and has never been tested with sectpmctl. The risk is that Windows will update the Secure Boot DBX
database which will prevent the successful unlocking of the LUKS key. In such case, you need the recovery key and need to redo the sectpmctl
installation, see 'Recovery' for more information.

It is recommended to only have one LUKS slot in use before installation, which is mostly slot 0. sectpmctl will additionally use slot 5 to
store the TPM key.

You can easily test the installation with virt-manager on a Ubuntu 22.04 host and a Ubuntu 22.04 guest. When creating a new VM you need to
configure the VM before it starts automatically. In the overview select 'OVMF_CODE_4M.secboot.fd' as firmware and then add a new 'TPM
emulated TIS 2.0' device. After installation of Ubuntu, you can start installing sectpmctl.

For transparency, the tpm2-tools commands for session encryption, provisioning, TOFU, seal, unseal, and password change are documented at the
end of this README. The commands for using Secure Boot are standard except for using the TPM as a key store for the db signing key. Take a
look at the source code to see how that works. If you are wondering, yes the PK and KEK keys are not stored at all in the current
implementation, they are simply not needed for anything.

## Features

* TPM2 backed FDE
* Provisions the TPM with sane settings in a minimal way
* Encrypts communication to and from the TPM
* Uses the trust on first use (TOFU) principle. The bonding happens at TPM provisioning time
* Passwordless or TPM + password option
  + Passwordless option is not influenced by DA lockout
  + TPM + Password option is influenced by DA lockout
  + Secure Boot signing is not influenced by DA lockout
* The Secure Boot signing key is backed by the TPM as well
* Zero TPM administrative overhead by managing Secure Boot instead of the TPM
  + Secure Boot is easier to manage
  + FDE key is only bound to the Secure Boot state, not to userspace
  + Maybe immune to BIOS updates
  + Immune to operating system upgrades
  + No postprocessing other than kernel and initrd signing required
  + Interrupted update of new kernels should still keep old kernels bootable
  + Additional installation of other bootloaders will not overwrite sectpmctl, they are placed alongside
* Can be integrated into a nearly fully automated preseed installation
  + The only upfront action is to clear TPM and Secure Boot
* The Secure Boot database is completely rebuilt with own keys and (by default) Microsoft keys for safety reasons
* Uses and integrates systemd-stub and systemd-boot as bootloader, does not invent a new one
* Optional omitting of Microsoft Secure Boot keys on supported hardware
* Option to forget the lockout authorization password set while TPM provisioning
* Option to set and forget an endorsement password while TPM provisioning
* Implemented in bash

Using a splash screen and the TPM + Password option does not work. If that happens you can enter the password blindly, it will work.

## Security and privacy options

### Lockout authorization password

Setting the authorization password to a random value without storing it enhances security because the lockout hierarchy can not be
modified without a password after TPM provisioning. This hierarchy also prevents accidental use of the tpm2_clear command. If you know
that you need access to the lockout hierarchy, you should remove the option '--forgetlockout' from the 'sudo sectpmctl tpm provisioning'
command in the installation section. If this option is not set, the lockout password is stored in '/var/lib/sectpmctl/keys/lockout.pwd'.
You can change this option also at a later time by reinstalling sectpmctl again (see the recovery section for how to do it).

### Endorsement authorization password

Setting the endorsement authorization password to a random value without storing it enhances privacy because the endorsement hierarchy
can be used to uniquely identify your device. If you know that you need access to the endorsement hierarchy, you should remove the
option '--setforgetendorsement' from the 'sudo sectpmctl tpm provisioning' command in the installation section. When this option is
not set, the endorsement authorization password will be empty. You can change this option also at a later time by reinstalling
sectpmctl again (see the recovery section for how to do it).

### One optional setting is dangerous (disabled by default)

When installing the sectpmct bootloader, the Microsoft keys are automatically uploaded to the Secure Boot database for your safety.
An option exists to suppress the uploading of the Microsoft keys. Together with a BIOS admin password, hardware without a crucial UEFI
OptionROM requirement like laptops with integrated graphics gains the protection that no other operating system can boot. This should probably
also increase security on another end. When sectpmctl is installed without a TPM password, the device will boot unattended (if there is no
BIOS startup password or if it has been removed). When the system would be able to execute bootloaders signed by Microsoft, it could be
possible that an attacker can boot software that tries to read out the memory from the last boot to get access to the LUKS key which is
still in the DDR RAM for some seconds. Disabling the booting of any other bootloader will prevent this relatively simple attack. And even if
the attacker can put his own or Microsoft keys into the Secure Boot database, sectpmctl rejects to boot automatically in the first place
because PCR 7 would be invalid. When this option is used together with a BIOS administrator password (with or without the TPM password),
this should also increase protection from the RAM attack if the laptop is stolen when on standby provided the attacker is not able to break
the BIOS administrator password. Another benefit is, when the device is stolen, that the thief can not sell the device anymore as it won't boot
any other operating system.

But this option is highly dangerous. When it is used on a device (typically servers and desktops or laptops with a dedicated PCI graphic card)
where the hardware strictly requires the Microsoft keys you will for sure at least semi-brick or completely brick the device.

**Do NOT use the --withoutmicrosoftkeys option of the sectpmctl boot install tool when:**

 * You don't know what the Microsoft UEFI CA key is used for
 * You have a dedicated NVidia RTX/GTX or AMD Radeon graphic card in a desktop or laptop
 * You have PCI cards in use which are related to booting (storage, network, etc)

Do use the option with care when:

 * You know the implications and have a supported device

In the case of graphic cards for example, when omitting the Microsoft keys, the screen will stay black when you power on the device. It will
not even work when the operating system is finished booting. If you are (very) lucky, you could maybe navigate blindly in the BIOS to disable
Secure Boot. Then, on the next start, the graphic card will function again. You can then restore the Secure Boot factory keys and enable Secure
Boot again. Another option is maybe to buy a very old graphics card or a CPU with integrated graphics to recover. On laptops, it is not
possible to switch to another graphic card for booting and the brick could be final, immutable, and can maybe never be recovered.

The sbctl project has a FAQ for the Microsoft keys: https://github.com/Foxboron/sbctl/wiki/FAQ#option-rom

This option will only work when you enter the Clear Mode in the Secure Boot BIOS settings, that is when the complete Secure Boot database
is empty. If you enter the Setup Mode (only the PK key is cleared instead of the complete Secure Boot database) this option won't work.

Differentiation of the Microsoft Windows and the Microsoft UEFI key is currently not done. Either both or none will be installed.

**You have been warned, it is highly possible to destroy your system without being able to fix it! Do an internet search before using this
option and ask somebody who might know if it could work. If you brick your device you are on your own. Use at your own risk!**

## Build and install tpmsbsigntool

You can either install the prebuild version or follow the build instructions:

### Prebuild installation

```
wget https://github.com/telekom-mms/tpmsbsigntool/releases/download/0.9.4-2/tpmsbsigntool_0.9.4-2_amd64.deb
sudo dpkg -i tpmsbsigntool_0.9.4-2_amd64.deb
sudo apt install -yf
```

### Build instructions

```
sudo apt install -y git devscripts debhelper-compat gcc-multilib binutils-dev libssl-dev \
  openssl pkg-config automake uuid-dev help2man gnu-efi tpm2-openssl

git clone https://github.com/telekom-mms/tpmsbsigntool.git

cd tpmsbsigntool
debuild -b -uc -us
cd ..

sudo dpkg -i ./tpmsbsigntool_0.9.4-2_amd64.deb
sudo apt install -yf
```

Alternatively you can build the package with docker (which needs to be able to run with user permissions):

```
git clone https://github.com/T-Systems-MMS/tpmsbsigntool.git

cd tpmsbsigntool
./docker.sh

sudo dpkg -i ./tpmsbsigntool_0.9.4-2_amd64.deb
sudo apt install -yf
cd ..
```

## Build sectpmctl

You can ignore the 'debsign: gpg error occurred!  Aborting....' error when building yourself.

```
sudo apt install -y debhelper efibootmgr efitools sbsigntool binutils mokutil dkms systemd udev \
  util-linux gdisk openssl uuid-runtime tpm2-tools fdisk

git clone https://github.com/T-Systems-MMS/sectpmctl.git

cd sectpmctl
make package_build
cd ..
```

## Install sectpmctl

Warning: After removing grub and shim there is no alternative than to complete the installation, otherwise your system will most probably
not boot anymore.

### Prerequisite

#### Secure Boot preparations

Your BIOS has to be in Secure Boot Setup Mode. That means that your BIOS need to have Secure Boot enabled and that all keys are cleared. You
can do so by entering your BIOS, enabling Secure Boot, and finding inside the Secure Boot section the button to "Clear all keys".

We never came across a BIOS which does not offer a way to enter Secure Boot Setup Mode. If your BIOS supports listing all keys, after entering
the setup mode, the number of keys of all databases should be zero. If your Secure Boot settings are grayed out, you most probably
have to set a BIOS administrator first.

First check if your Secure Boot is enabled and cleared by executing these two commands:

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

As sectpmctl will provision your TPM in a minimal way it is required to start the installation with a cleared TPM. That can be achieved in
three ways:

- Clear the TPM (sometimes also called Security Chip) in the BIOS if available. Some BIOS types require you to press a key after a reboot to
clear the TPM.
- Use Windows to disable TPM auto-provisioning and clear the TPM by using PowerShell commands, followed by a reboot.
- Execute in Linux: "echo 5 | sudo tee /sys/class/tpm/tpm0/ppi/request" and reboot.

Be warned that if you put already keys into the TPM, they will be lost by the clearing.

Be also warned that when a TPM lockout password is set and you try to clear the TPM with software commands by entering a wrong lockout
password, there will be a time penalty until you can try again. The above three ways to clear should allow you to clear the TPM even when you
entered a wrong lockout password.

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

The command which will be executed later while installing, "sectpmctl tpm provisioning", should run successfully with a cleared TPM and the
the output should look like this:

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

The provisioning will set a random lockout password which is stored in '/var/lib/sectpmctl/keys/lockout.pwd', set sane dictionary attack
lockout time penalty settings and create two TPM primary keys, one with the dictionary attack lockout flag (DA) and one without (NODA).

The following DA lockout values are set:

- Wrong password retry count = 32 tries
- Recovery time = 10 minutes
- Lockout recovery time = 30 minutes

Unsealing the LUKS key while booting without TPM + password and signing of kernels and kernel modules is done by using the NODA primary key to
not break updates in case of a dictionary lockout situation. When using the TPM + password option, the unsealing while booting is done with the
DA key, while keep using the NODA key for signing kernels and kernel modules. 

All generated keys, passwords, or serialized keys are stored in '/var/lib/sectpmctl/keys'.

### Installation

```
# 1. Point of no return, you need to complete at least until the following reboot command
sudo apt remove --allow-remove-essential "grub*" "shim*"
sudo dpkg -i sectpmctl_1.1.3-1_amd64.deb
sudo apt install -yf

# optionally disable swap while keys are created
sudo swapoff -a

# 2. TPM Provisioning
sudo sectpmctl tpm provisioning --forgetlockout --setforgetendorsement


# 3. Cleanup leftovers from grub, shim, and windows with efibootmgr
while [[ $(efibootmgr | grep -c -m 1 "Windows Boot Manager") -gt 0 ]]
do
  entryId=$(efibootmgr -v | grep -m 1 -i "Windows Boot Manager" | sed -e 's/^Boot\([0-9]\+\)\(.*\)$/\1/')
  sudo efibootmgr -q -b "${entryId}" -B
done
while [[ $(efibootmgr | grep -c -m 1 "ubuntu") -gt 0 ]]
do
  entryId=$(efibootmgr -v | grep -m 1 -i "ubuntu" | sed -e 's/^Boot\([0-9]\+\)\(.*\)$/\1/')
  sudo efibootmgr -q -b "${entryId}" -B
done
while [[ $(efibootmgr | grep -c -m 1 "SECTPMCTL Bootloader") -gt 0 ]]
do
  entryId=$(efibootmgr -v | grep -m 1 -i "SECTPMCTL Bootloader" | sed -e 's/^Boot\([0-9]\+\)\(.*\)$/\1/')
  sudo efibootmgr -q -b "${entryId}" -B
done


# 4. Now migrate the boot partition to root, the following partition table is assumed, change all
# references according to your device and partition names and numbers:

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

# TODO: Describe how to reinstall or rebuild all installed or build DKMS kernel
# modules to have them resigned.

# After this reboot your current LUKS password is still required
sudo reboot


# 6. Install the LUKS TPM implementation
# optionally disable swap while keys are created
sudo swapoff -a

# Now your machine has its own set of Secure Boot keys, test it
sudo sectpmctl boot test

# Install the LUKS TPM key. Enter your current LUKS key when asked.
cat > install_tpm.sh <<__EOT
#! /bin/bash
echo -n "Enter TPM Password: "
read -sr tpmpwda
echo
echo -n "Enter TPM Password again: "
read -sr tpmpwdb
echo
if [[ "x\${tpmpwda}" == "x\${tpmpwdb}" ]]; then
  sudo sectpmctl tpm install --setrecoverykey --password "\${tpmpwda}"
else
  echo "Passwords don't match. Exit"
  exit 1
fi
__EOT
chmod +x install_tpm.sh
./install_tpm.sh

# STORE THE PRINTED RECOVERY KEY NOW!!!
# SCROLL UP A BIT IF IT GET'S OUT OF SIGHT!!!

# Reboot to test the installation
sudo reboot
```

The 'sectpmctl tpm install' command will print out the recovery key. It is highly recommended to store this key in a safe location. Without
this key, you can lose all your data when the TPM breaks or when accessing your hard disk on another machine. You have been warned!

The recovery key will be printed first, then the bootloader is updated. It can happen that the recovery key is not visible after the
installation. Then you need to scroll up a bit to see it. The recovery key is built by eight groups with eight characters from 0 to 9 and a to
f which sums up to 256bit. If this is too long you can decrease the number of groups or the group length with the 'sectpmctl tpm' options
'--recoverygroups' and '--recoverygrouplength'. To create a shorter 192bit recovery key you can do so with 8 groups and a group length of 6.

After a reboot, the LUKS partition should decrypt automatically and the installation is complete.

You can then do some bootloader configuration by editing '/etc/sectpmctl/boot.conf'. Currently, a splash screen should not be activated. It
is disabled by default. The kernel option "quiet" is supported but disabled as well by default. Remember to update the bootloader afterward
by executing:

```
sudo sectpmctl boot update
```

followed by a reboot. You can also use the bootctl command for basic tasks like listing the bootable kernels:

```
sudo bootctl list
```

By default, only kernels signed by Canonical are considered to be shown in the boot list. Unsigned kernels are ignored for safety reasons.
If you want to have support for all kernels, you can edit '/etc/sectpmctl/boot.conf', set 'SKIP_UNSIGNED_KERNELS' to 'false', and update the
bootloader with 'sectpmctl boot update'.

If the password option has been used, the current password can be changed at runtime. The TPM should not be in the DA lockout mode, otherwise
you have to wait up to 10 minutes.

```
cat > change_tpm_password.sh <<__EOT
#! /bin/bash
echo -n "Enter old TPM Password: "
read -sr tpmpwdold
echo
echo -n "Enter new TPM Password: "
read -sr tpmpwda
echo
echo -n "Enter new TPM Password again: "
read -sr tpmpwdb
echo
if [[ "x\${tpmpwda}" == "x\${tpmpwdb}" ]]; then
  sudo sectpmctl key changepassword --handle 0x81000102 --oldpassword "\${tpmpwdold}" --password "\${tpmpwda}"
else
  echo "Passwords don't match. Exit"
  exit 1
fi
__EOT
chmod +x change_tpm_password.sh
./change_tpm_password.sh
```

If the current password is lost, a new password can be set with the recovery key by installing again:

```
sectpmctl tpm install --setrecoverykey --password "mynewpassword"
```
      
## Updates

Remember that entering the recovery key while booting is the only option when sectpmctl will not unlock automatically anymore. See 'Recovery'
for how to fix it.

### Kernel or kernel module updates

Kernel or kernel module updates will not create any problems.  Whenever a kernel is installed or a DKMS module is updated or installed,
the corresponding hooks are called to automatically sign the kernel and/or kernel modules in a very similar way as DKMS and grub are doing
updates.

### Userspace updates

No userspace application except bootloaders should be able to cause any problems. It is better to not install any other bootloader. The
UEFI specification allows for many bootloaders to be installed in parallel. No other bootloader will overwrite sectpmctl but most probably
change the boot order. In such case, you can enter the boot menu of your BIOS (often the F12 key or such) and select sectpmctl again as boot
entry. You can do it also permanently by using the efibootmgr command although it could be a bit of a fiddle.

### BIOS Updates, eventually even with a Secure Boot database update

It seems that BIOS updates on Lenovo Thinkpads won't cause problems as they seem to keep the Secure Boot database and won't reset the TPM.
All tested BIOS updates done so far did not result in preventing unsealing.

On the other hand on Gigabyte  X570S AERO motherboards,  the Secure Boot database seems to be reset during BIOS update, with the result that
the recovery password needs to be entered on the next boot and sectpmctl needs to be installed again.

If you know that Secure Boot and TPM stay stable there should be no problem in updating, otherwise, keep your recovery password within reach.
In a future version, binding to PCR 0 and handling BIOS updates could be implemented. That requires either integration with fwupdatemgr or the
execution of a command in front of the BIOS update.

### Custom kernels or kernel modules

After installing sectpmctl, a key (db) to sign kernels and kernel modules is stored in the TPM in a serialized form in
'/var/lib/sectpmctl/keys/db.obj' for use with tpmsbsigntool. The key password is stored in '/var/lib/sectpmctl/keys/db.pwd'

You normally don't need to use the db key manually. DKMS and kernel hooks are integrated and execute the sign commands automatically
for every kind of Ubuntu upgrade. Two helper scripts behave like sbsign and kmodsign in '/usr/lib/sectpmctl/scripts' when you
need to sign things manually:

- sbsign.sh
- kmodsign.sh

You can even link the helper scripts over the sbsigntool executables by leveraging a Debian config package if you need to do so,
for example to support the maintainance of commercial antivirus applications or such.

You then need to supply a key and a certificate which are stored in '/var/lib/sectpmctl/keys/':

- db.obj (key)
- db.cer (certificate)
- db.crt (certificate)

Depending on the tool you either need the CER or the CRT file as a certificate.

Please read the helper scripts before manually using them as they have specific needs for rewriting parameters. Hopefully the patches of
tpmsbsigntool can be merged upstream in sbsigntool in the future.

## Recovery

In case of a changed Secure Boot database, sectpmctl will not unlock anymore. In that case, you can simply repeat the sectpmctl installation.
First, clear the Secure Boot database, then clear the TPM and finally repeat all steps except 1. and 4. from the installation. It is possible
to do it more fine-grained which will be documented in a later release.

You could then omit the '--setrecoverykey' option in the 'sectpmctl tpm install' command to keep your current recovery key.

## TPM2 Internals

You can test the implementation on a fresh Ubuntu installation with a cleared TPM. The following snippets from Provisioning, Sealing with TPM
password, Unsealing with TPM password, and Changing the TPM password are executable in this order.

### Used handles

The following persistent handles are created after provisioning and installation. The keyed hash is using one of the two parent objects.

| Handle | Object |
| ------ | ------ |
| 0x81000100 | Parent object with DA |
| 0x81000101 | Parent object with NODA |
| 0x81000102 | Keyed hash of LUKS key |

### List of PCR Values on Ubuntu

| PCR | Description |
| --- | ----------- |
| 0 | BIOS |
| 1 | BIOS Config |
| 2 | Option ROM |
| 3 | Option ROM Config |
| 4 | Bootloaders and EFI Blobs |
| 5 | GPT Partition Table |
| 6 | Resume Events (seems not to work on Linux) |
| 7 | SecureBoot State |
| 8 | GRUB Bootloader Config |
| 9 | GRUB Bootloader Files |
| 10 |  |
| 11 | sectpmctl |
| 12 |  |
| 13 |  |
| 14 | shim Bootloader MOK |

### List of PCR values used by sectpmctl

| PCR | value |
| --- | ----- |
| 7 | Secureboot state |
| 8 | zero |
| 9 | zero |
| 11 | LUKS header |
| 14 | zero |

PCR8, 9, and 14 will be zero when sectpmctl is installed. MOK is not and should not be used. This is verified by binding the LUKS key to this
three zero values.

PCR11, the LUKS header, is measured while sealing in the installation and while unsealing by the initrd. It has a special purpose. After
unsealing the LUKS key in the initrd, PCR11 is extended with a random value. That blocks a second unsealing without having to extend a more
meaningful like PCR7.

### Provisioning

Performing TPM provisioning is required for advanced usage. The TPM has to be partitioned and secured. This implementation does not make use
of the endorsement key, some users want to disable this hierarchy anyway for privacy reasons. It also doesn't set passwords for the owner
hierarchy because that will sooner or later create problems with software that simply would not allow using an owner password, tpm2-topt for
example. The root user would be able to create new primary keys or even delete them, but that should not break security.

The two public keys 'tpm_owner.pub' and 'tpm_owner_noda.pub' play an important role. They are used for session encryption, but more
importantly, they build the foundation of the TOFU principle. These public keys are used to establish a TPM session when unsealing in the
initrd. If the corresponding private key is not inside the TPM, then the communication is directly rejected. The public key is copied into the
initrd and of course signed by Secure Boot so that manipulation of the public key won't boot. Deleting the private key in the TPM or using a
different TPM also won't boot. Only when the initrd finds the private keys created at provisioning time together with the initrds public key,
the encrypted session is established.

```
# Clear the TPM
tpm2_clear

# Set lockout values
tpm2_dictionarylockout --max-tries=32 --recovery-time=600 --lockout-recovery-time=1800 \
  --setup-parameters

# The lockout authorization password is stored in plain text inside the encrypted root partition
tpm2_changeauth --object-context=lockout "high entropy password"

# Create the first primary key with DA flag, store the public key for TOFU
tpm2_createprimary --hierarchy=o --key-algorithm=rsa --key-context=prim.ctx
tpm2_evictcontrol --hierarchy=o --object-context=prim.ctx "0x81000100"
tpm2_readpublic --object-context="0x81000100" --serialized-handle="tpm_owner.pub"

# Create the second primary key with NODA flag, store the public key for TOFU
tpm2_createprimary --hierarchy=o --key-algorithm=rsa --key-context=prim_noda.ctx \
    --attributes="fixedtpm|fixedparent|sensitivedataorigin|userwithauth|restricted|decrypt|noda"
tpm2_evictcontrol --hierarchy=o --object-context=prim_noda.ctx "0x81000101"
tpm2_readpublic --object-context="0x81000101" --serialized-handle="tpm_owner_noda.pub"
```

### Session encryption and TOFU

When a session is established for sealing or unsealing, the public keys from the provisioning are used

```
# The tpm_owner_noda private key is available in the TPM

tpm2_startauthsession --policy-session --session="session.ctx" --key-context="tpm_owner_noda.pub"

tpm2_sessionconfig "session.ctx"
# -> Session-Attributes: continuesession|decrypt|encrypt
```

```
# The tpm_owner_noda private key is not available in the TPM

tpm2_startauthsession --policy-session --session="session.ctx" --key-context="tpm_owner_noda.pub"
# -> ERROR: Esys_StartAuthSession(0x18B) - tpm:handle(1):the handle is not correct for the use
```

### Sealing with TPM password

```
# Generate the secret
echo mysecret > INPUT_SECRET_FILE

# Foresee or read the PCR values into "pcr_values.dat"
tpm2_pcrread "sha256:7,8,9,11,14" --output="pcr_values.dat"

# Create trial PCR with authvalue policy session
tpm2_startauthsession --session="trialsession.ctx"

tpm2_policypcr --session="trialsession.ctx" --pcr-list="sha256:7,8,9,11,14" \
  --pcr="pcr_values.dat" --policy="pcr.policy"

tpm2_policyauthvalue --session="trialsession.ctx" --policy="pcr.policy"

tpm2_flushcontext "trialsession.ctx"

# Connect encrypted to the TPM with key enforcement (TOFU)
tpm2_startauthsession --policy-session --session="session.ctx" --key-context="tpm_owner.pub"

tpm2_sessionconfig "session.ctx"
# -> Session-Attributes: continuesession|decrypt|encrypt

# Seal the secret
tpm2_create --session="session.ctx" --hash-algorithm=sha256 --public="pcr_seal_key.pub" \
  --private="pcr_seal_key.priv" --sealing-input="INPUT_SECRET_FILE" \
  --parent-context="0x81000100" --policy="pcr.policy" --attributes="fixedtpm|fixedparent" \
  --key-auth="hex:11223344"

tpm2_flushcontext "session.ctx"

# Remove current object in handle, may fail if empty
tpm2_evictcontrol --object-context="0x81000202" --hierarchy=o 2> /dev/null > /dev/null

tpm2_load --parent-context="0x81000100" --public="pcr_seal_key.pub" \
  --private="pcr_seal_key.priv" --name="pcr_seal_key.name" --key-context="pcr_seal_key.ctx"

# Store secret
tpm2_evictcontrol --object-context="pcr_seal_key.ctx" "0x81000202" --hierarchy=o
```

### Unsealing with TPM password

```
tpm2_startauthsession --policy-session --session="session.ctx" --key-context="tpm_owner.pub"

tpm2_sessionconfig "session.ctx"
# -> Session-Attributes: continuesession|decrypt|encrypt

tpm2_policypcr --session="session.ctx" --pcr-list="sha256:7,8,9,11,14"

tpm2_policyauthvalue --session="session.ctx"

# Unseal the secret
tpm2_unseal --auth="session:session.ctx+hex:11223344" --object-context="0x81000202"

tpm2_flushcontext "session.ctx"
```

### Changing the TPM password

```
tpm2_readpublic --object-context="0x81000202" --output="key.pub"

#Change authorisation
tpm2_changeauth --object-context="0x81000202" --parent-context="0x81000100" \
  --private="new.priv" --object-auth="hex:11223344" "hex:ff11ff11"

tpm2_evictcontrol --object-context="0x81000202" --hierarchy=o

tpm2_load --parent-context="0x81000100" --public="key.pub" --private="new.priv" \
  --name="new.name" --key-context="new.ctx"

# Store the new authorization
tpm2_evictcontrol --object-context="new.ctx" "0x81000202" --hierarchy=o
```

### Authorized policies

The current implementation doesn't need authorized policies. The next release will most probably include them to do advanced updates without
the need for a recovery key.

## Bugs and problems found

When many TPM (policy) sessions are created and not freed after use, a kernel bug could be triggered. When that happens, the TPM will not
answer anymore to commands. A dmesg output will then show problems. The expected behavior is that tpm2 commands will return an error code.
Therefore a timeout has been implemented in the key tool to prevent endless waiting. To prevent this problem at boot time (the sessions seem
not be cleared automatically on booting) all TPM sessions are flushed before unsealing in the initrd.

During the unseal at boot time the kernel may load (some additional) kernel modules.
If this module loading results in a modification to the TPM PCR registers - especially while sectpmctl is doing the unseal - the TPM will
return the error code `TPM_RC_PCR_CHANGED`, which prevents the unsealing of the LUKS partition.

To solve this problem a loop is implemented to simply retry unsealing 5 times with a sleep of 2 seconds in between. It seems to be difficult to
have a stable parsing of this specific error code, therefore the loop is triggered on all TPM errors at boot time.


### Acer laptops quirks

First to know is that you have to set a BIOS administrator password. Otherwise, the Secure Boot settings are grayed out and cannot be changed. 

An installation on an Acer Swift 3 SF314-42 laptop caused some problems which needed changes in the source code to enable an installation:

* The Secure Boot Signature Database (DB) maybe not be cleared by entering Setup Mode. Fix: Clear it before installation with
`efi-updatevar -d 0 db`.
* The Secure Boot Forbidden Signature Database (DBX) could not be cleared by efi-updatevar. Workaround: Comment out clearing and updating of
DBX in sectpmctl-boot.
* tpm2_clear fails. Fix: Clear the TPM inside the BIOS, Windows, or by executing `echo 5 | sudo tee /sys/class/tpm/tpm0/ppi/request` and remove
tpm2_clear in sectpmctl-tpm.
* tpm2_dictionarylockout fails. That's not good. If the lockout settings are reasonable already, the call can be removed in sectpmctl-tpm.

After a second installation, tpm2_clear and tpm2_dictionarylockout worked unexpectedly. So that could be related to a BIOS or kernel bug
and maybe fixed already.

These tools can be used to read the current Secure Boot and TPM settings:

```
mokutil --sb-state
efi-readvar
sudo tpm2_getcap properties-variable
```

### Gigabyte mainboards

Be careful with BIOS updates. They may delete the Secure Boot database which then makes use of the recovery password necessary.

## Changelog

* 1.1.4
  + Added support for release pipeline

* 1.1.3
  + Fixed TPM_RC_PCR_CHANGED problem while unsealing without password at boot time
  + Added check to stop quickly when a wrong LUKS password has been provided
  + Added documentation and fixed build instructions
  + Added optional ommitting of Microsoft Secure Boot keys on supported hardware
  + Added option to forget the lockout authorization password set while TPM provisioning
  + Added option to set and forget an endorsement password while TPM provisioning
  + Added kernel global extra command line to bootloader
  + Fixed Esys_CreateLoaded error

* 1.1.2
  + Added Debian protected flag and added linking for the signing wrappers

* 1.1.1
  + Fixed cleanup bugs in sectpmctl key
  + Added documentation

* 1.1.0
  + Added support for TPM + Password
  + Added documentation

* 1.0.0
  + Initial upload

## Disclaimer

Every piece of information or code in this repository is written and collected with the best intentions in mind. We do not
warrant that it is complete, correct, or that it is working on your platform. We provide everything as is and try to fix bugs and
security issues as soon as possible. Currently, Ubuntu 22.04 is the only supported distribution. Use at your own risk.

