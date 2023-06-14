# Example Base VM Image

We want all our servers to have the same (or as similar as possible) state, and manage that state with IaC.

# Packer file, base-image.pkr.hcl

Packer

- creates a virtual machine with Ubuntu 22.04 cloud image, using QEMU and KVM. So, you need to have KVM installed on your local, or wherever you’re building this image
- the output image format will be qcow2, which is a QEMU image.
- mounts below files to the VM. `cd_label` absolutely needs to be named “cidata.” Otherwise it won’t mount.

```
cd_files = ["cloud-init/user-data", "cloud-init/meta-data", "cloud-init/network-config"]
cd_label = "cidata"
```

- to be able to gracefully shutdown the VM, you have to pass

```
shutdown_command = "sudo shutdown -P now"
```

Below is the build stage of the Packer file:

```
build {
  sources = ["source.qemu.template"]

  # wait for cloud-init to successfully finish
  provisioner "shell" {
    inline = [
      "cloud-init status --wait > /dev/null 2>&1"
    ]
  }

  provisioner "ansible-local" {
    playbook_file = "ansible/playbook.yml"
  }
}
```

After the VM is up, Packer will connect to it via SSH on port 8324 (it will wait 1 minute before connecting). It will wait for the cloud-init to finish. cloud-init is like Ubuntu’s pre-boot config. It will get executed when your first installing the OS. We’ll explain what our cloud-init configs do in the next section.

After the cloud init, the Ansible playbook is copied inside the VM and run locally there. It will be explained in the third section.

# cloud-init

## network-config

```
version: 2
ethernets:
  eth0:
    dhcp4: yes
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
  ens3:
    dhcp4: yes
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
```

Without this, we won’t be able to connect to the internet because we won’t have a default network that would allow it.

## user-data

- Disable root login.
- Disable SSH password authentication.
- Create ubuntu user, add it to the sudo group and give it passwordless sudo access. Also add pgeo publickey to its authorized_keys.
- update apt cache, upgrade, and install python3.
- Install ansible using pup and install community.general packages.
- Switch SSH port to 8324.
- Disable cloud-init so that it won’t be run everytime the server is restarted.
- `sed -ie 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 elevator=noop"/' /etc/default/grub` couldn’t really understand this one to be honest, but without it the networking doesn’t work.
- Use Ubuntu TR mirrors.
- Grow the disk to the VM disk size, which was appointed as 20GB by us via the Packer file.

## meta-data

No metadata. But that file should be there. cloud-init just asks for it.

# Ansible Playbook

## playbook.yml

This is for general use.

- Install docker and docker-compose.
- Install basic, necessary software.
- Set up firewall rules.