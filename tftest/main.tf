terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.1"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://10.0.0.25:8006/"
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent    = true
    username = "timjtc"
  }
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

data "proxmox_virtual_environment_vms" "tp" {
  filter {
    name   = "name"
    values = ["almalinux-9-genericcloud-tp"]
  }
}

resource "proxmox_virtual_environment_vm" "vtest1" {
  name      = "vtest1"
  node_name = "shlm1"

  clone {
    vm_id = data.proxmox_virtual_environment_vms.tp.vms[0].vm_id
  }

  cpu {
    type = "host"
    cores = 2
  }

  memory {
    dedicated = 1536    # MB
  }

  disk {
    datastore_id = "zfs1s"
    interface    = "scsi0"
    size         = 10   # GB
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id = "lvm1h"
    user_account {
      username = "admin"
      password = var.admin_password
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }
  }
}

output "vm_ip" {
  value = proxmox_virtual_environment_vm.vtest1.ipv4_addresses
}