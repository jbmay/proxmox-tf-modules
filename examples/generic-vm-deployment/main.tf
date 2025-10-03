locals {
  user    = "example-vm-user"
  ssh_key = "ssh public key for vm access"
  # password 'changeme' hashed with `mkpasswd -m sha-512 -s`
  user_password = "$6$quMUtwz30SYBIpmy$VT8l/ZmGxJH/uz9XixzQTcMDFdtzjKXf0lu35iRqv5CrGffWe6IL.LGWYsULSTdv2q0S0sqbTn0QZK59hf260/"
  proxmox_node  = "pve0"
  # Name of the template on node pve0 to clone for the VM creation
  template_name = "ubuntu-docker-2204-template.v2"
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.70.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.3"
    }
    dns = {
      source  = "hashicorp/dns"
      version = ">=3.4.1"
    }
  }
  backend "s3" {
    bucket    = "example-tf"
    key       = "example-docker-vm-deployment/terraform.tfstate"
    endpoints = { s3 = "https://s3.us-west-002.backblazeb2.com" }
    region    = "us-east-1"

    access_key                  = "your-access-key"
    secret_key                  = "your-secret-key"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

# variable "api_id" {
#   type = string
# }

# variable "api_token" {
#   type = string
# }

variable "ssh_user" {
  type = string
}

variable "ssh_password" {
  type = string
}

provider "proxmox" {
  endpoint = "https://your-proxmox-hostname.com:8006/api2/json"

  # api_token = "${var.api_id}=${var.api_token}"
  #TODO: uncomment api_token and configure sudo user for terraform on all nodes to replace user/password for provider config
  username = var.ssh_user
  password = var.ssh_password

  # uncomment (unless on Windows...)
  tmp_dir = "/var/tmp"

  ssh {
    agent = true
    # TODO: uncomment and configure if using api_token instead of password
    # username = var.ssh_user
  }
}

module "example_docker_vm" {
  source = "../../modules/generic-vm"

  template_name           = local.template_name
  root_disk_datastore_id  = "local-zfs"
  cloud_init_datastore_id = "local-zfs"
  name_prefix             = "example-docker"
  proxmox_node            = local.proxmox_node
  user                    = local.user
  user_password           = local.user_password
  ssh_key                 = local.ssh_key
  # Snippet datastore can be any datastore that exists on each proxmox node. This example lists an NFS share that exists on each node
  snippet_datastore = "some-nfs-share"
  cpu_type          = "host"
  root_disk_size    = 10

}

output "vm_ipv4_addresses" {
  value = module.example_docker_vm.vm_ipv4_address
}
