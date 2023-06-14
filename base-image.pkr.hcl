source "qemu" "template" {
  vm_name   = "example-base-image-vm"
  cpus      = "2"
  memory    = "2048"
  disk_size = "20G"

  iso_url      = "https://cloud-images.ubuntu.com/jammy/20230317/jammy-server-cloudimg-amd64.img"
  iso_checksum = "sha256:31cd56b1448f201602facb3a9d110af3aefe2401d7c002500ef08ec7a00ca4f5"

  communicator            = "ssh"
  ssh_timeout             = "1h"
  ssh_username            = "ubuntu"
  ssh_port                = 8324
  skip_nat_mapping        = true
  pause_before_connecting = "1m"
  ssh_private_key_file    = <private-key-file:string>

  output_directory = "output"

  boot_wait = "1m"

  accelerator = "kvm"

  format           = "qcow2"
  use_backing_file = false
  disk_image       = true
  disk_compression = true

  headless            = true
  use_default_display = false
  vnc_bind_address    = "127.0.0.1"

  cd_files = ["cloud-init/user-data", "cloud-init/meta-data", "cloud-init/network-config"]
  cd_label = "cidata"

  qemuargs = [
    ["-serial", "mon:stdio"],
  ]

  shutdown_command  = "sudo shutdown -P now"
}

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
