#!/bin/sh

# mkc6vm.sh - shell script for the easy creation of CentOS 6.x qemu / KVM / libvirt VMs using packer
#
# by Dan MacDonald

# This script depends upon packer (tested with v1.1.1) and virtinst to run

# Set this variable every time you run mkc6vm.sh. This will be the hostname and the name of the VM:

QemuName="VMname"

# Set the following three variables at least once, before your first run:

# Full path to use to save the qemu disk image to:

QemuPath="/home/dan/qemu"

# Full path and filename of the CentOS 6.x install ISO:

QemuFile="/home/dan/CentOS-6.9-x86_64-minimal.iso"

# qemu VM RAM in MB

QemuRAM="1024"

# That's it! You shouldn't need to change anything after this line.

echo "Creating a temporary working directory"
mkdir /tmp/$QemuName

echo "Creating the packer JSON file"

cat >/tmp/$QemuName/packer-c6-qemu.json <<EOF
{
  "builders":
  [
    {
      "type": "qemu",
      "iso_url": "$QemuFile",
      "iso_checksum": "af4a1640c0c6f348c6c41f1ea9e192a2",
      "iso_checksum_type": "md5",
      "output_directory": "$QemuPath/$QemuName",
      "shutdown_command": "shutdown -P now",
      "disk_size": 5000,
      "format": "qcow2",
      "headless": false,
      "accelerator": "kvm",
      "http_directory": "/tmp/$QemuName",
      "http_port_min": 10082,
      "http_port_max": 10089,
      "ssh_host_port_min": 2222,
      "ssh_host_port_max": 2229,
      "ssh_username": "root",
      "ssh_password": "corn",
      "ssh_wait_timeout": "10000s",
      "vm_name": "$QemuName",
      "net_device": "virtio-net",
      "disk_interface": "virtio",
      "boot_wait": "5s",
      "boot_command": [
        "<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos6-ks.cfg<enter><wait>"
      ]
    }
  ],
  "provisioners": [{
	"type": "shell",
    "inline": [
      "echo 'Update base packages'",
      "yum -y update",
      "echo 'Remove cached udev network interfaces'",
      "rm /etc/udev/rules.d/70-persistent-net.rules",
      "echo 'Remove incorrect MAC address from the eth0 network script'",
      "sed -i '/^HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0",
      "echo 'Add hostname to hosts file'",
      "sed -i 's/$/\\\ $QemuName/' /etc/hosts",
      "echo 'Configure SSH server for using keys only'",
      "sed -i -e 's/#Pubkey/Pubkey/' -e 's/PasswordAuthentication\\\ yes/PasswordAuthentication\\\ no/g' -e 's/#PermitRootLogin\\\ yes/PermitRootLogin\\\ no/' /etc/ssh/sshd_config",
      "echo 'Add non-root user ans and add user to the wheel group'",
      "useradd -g users -G wheel -d /home/ans -s /bin/bash -p '$1$xm.sIXpk$QRa2MRwgAc4fnd4.WoVt40' ans",
      "echo 'Make .ssh directory for new user'",
      "mkdir /home/ans/.ssh && chown ans:users /home/ans/.ssh",
      "echo 'Install EPEL repo and packages'",
      "yum -y install epel-release nss-mdns"
    ]},
    {
    "type": "file",
    "source": "/home/dan/.ssh/id_rsa.pub",
    "destination": "/home/ans/.ssh/authorized_keys"
    },
    {
	"type": "shell",
	"inline": [
	  "echo 'Set ownership of authorized SSH keys file'",
	  "chown ans:users /home/ans/.ssh/authorized_keys"
	]}
  ]
}
EOF

echo "Creating the CentOS 6.x Kickstart file"

cat >/tmp/$QemuName/centos6-ks.cfg <<EOF
text
skipx
install
url --url http://mirrorservice.org/sites/mirror.centos.org/6/os/x86_64/
repo --name=updates --baseurl=http://mirrorservice.org/sites/mirror.centos.org/6/updates/x86_64/
lang en_GB.UTF-8
keyboard uk
network --device eth0 --bootproto dhcp --hostname $QemuName
rootpw corn
firewall --disable
authconfig --enableshadow --passalgo=sha512
selinux --disabled
timezone --utc Europe/London
%include /tmp/kspre.cfg

services --enabled=network,sshd

reboot

%packages --nobase
at
acpid
avahi
cronie-noanacron
crontabs
logrotate
mailx
mlocate
openssh-clients
openssh-server
rsync
tmpwatch
vixie-cron
which
wget
yum
-biosdevname
-postfix
-prelink
%end

%pre
bootdrive=vda

if [ -f "/dev/$bootdrive" ] ; then
  exec < /dev/tty3 > /dev/tty3
  chvt 3
  echo "ERROR: Drive device does not exist at /dev/$bootdrive!"
  sleep 5
  halt -f
fi

cat >/tmp/kspre.cfg <<CFG
zerombr
bootloader --location=mbr --driveorder=$bootdrive --append="nomodeset"
clearpart --all --initlabel
part /boot --ondrive=$bootdrive --fstype ext4 --fsoptions="relatime,nodev" --size=512
part pv.1 --ondrive=$bootdrive --size 1 --grow
volgroup vg0 pv.1
logvol / --fstype ext4 --fsoptions="noatime,nodiratime,relatime,nodev" --name=root --vgname=vg0 --size=4096
logvol swap --fstype swap --name=swap --vgname=vg0 --size 1 --grow
CFG

%end

%post

%end
EOF

echo "Running packer and building the disk image"
packer build /tmp/$QemuName/packer-c6-qemu.json

echo "Installing the new VM for use with virsh and virt-manager"
virt-install -n $QemuName -r $QemuRAM --disk $QemuPath/$QemuName/$QemuName,device=disk,bus=virtio --noautoconsole --os-variant rhel6 --import

echo "Removing temporary directory"
rm -rf /tmp/$QemuName
