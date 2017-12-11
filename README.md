# Packer scripts for creating a minimal CentOS 6 qemu KVM virtual machine disk image

## By Dan MacDonald

I wanted to use packer to automate the process of creating barebones Centos 6 (initially - I'll be trying CentOS 7 next) VM disk images for use with qemu, primarily to assist me with learning ansible. The official packer docs are entirely AWS centric. Whilst I realise the widespread popularity of AWS, for educational purposes, spinning up VMs under qemu/kvm is much more cost effective, faster and less prone to errors for most Linux users. KVM VMs are much faster than Virtualbox/Vagrant VMs,  better integrated with the Linux kernel and fully open source, unlike VMWare. The qemu example given in the packer docs didn't work for me due to several errors and omissions in both the example packer qemu json file as well as the example kickstart file so I thought others might find this simple, working packer example useful.

These scripts have been tested with packer 1.1.1 under Ubuntu 17.10 amd64 with the CentOS 6.9 minimal amd64 install ISO. This script fixes the default CentOS network scripts so that DHCP works, configures SSH for use with your public key, creates a non-root user and installs Avahi so that you can discover the DHCP-assigned IP addresses of your VMs by running **avahi-browse** on your host after they have booted. The default password for the **ans** user in CentOS is **ans**. selinux and the firewall have been disabled.

You can create a replacement password hash for the non-root user with the command:


```
$ echo newpassword | openssl passwd -1 -stdin
```

After you have modified the paths, hostname etc in the json file as required and you have run **packer build packer-centos6-qemu.json** successfully, you can import the image for use with libvirt/virsh/virt-manager etc:

```
$ virt-install -n VMname -r 2048 --disk /path/to/image,device=disk,bus=virtio --noautoconsole --os-variant rhel6 --import
```

Substituting **VMname** for the name to give the VM under libvirt, **2048** for the number of MBs of RAM you wish the VM to have and **/path/to/image** with the full path to the VM image. 

**mkc6vm.sh** provides a very simple example of how to use a shell script to fully automate the creation of new CentOS 6 qemu VMs with packer. See the scripts comments for usage instructions.
