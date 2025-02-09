locals {
  vm_ssh_user = "example-vm-user"
  vm_ssh_key  = "ssh public key for vm access"
  # password `password` hashed with command `mkpasswd -m sha-512 -s`
  vm_user_password = "$6$lYn1N2zlfWxOnRrC$bSBBiEFdphiF.uG7Md0NsYerF0zfqREKI/SJsxG.0LJIZRRVwwsf.NpG9lY8lm09r5yFbSDlFXpodXmVqWzxR0"
  node_list        = ["pve0", "pve1", "pve2"]
  # Proxmox VM template that exists on each proxmox node you want to deploy a k3s node onto. Should have qemu-guest-agent installed and configured to run
  template_name = "ubuntu-server-2204-base-template.v2"
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
  }
  # Configure whatever backend you use, this example shows using backblaze b2
  backend "s3" {
    bucket    = "example-tf"
    key       = "k3s-example-deployment/terraform.tfstate"
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

# bpg proxmox provider supports multiple ways to authenticate with proxmox. This example shows configuring a proxmox user and password that is uncommented, and a commented out configuration to use an API token instead
# Note that the bpg provider requires SSH access to the Proxmox nodes to get around some limitations of the Proxmox API so if an API user is configured then the SSH settings still need to be configured.
# If an API key is used and the host you run terraform/tofu applies from has an SSH agent configured for the connection to your proxmox host, then you don't need to provide the SSH password to the provider, only the username

# variable "api_id" {
#   type = string
#   description = "Proxmox API token id"
# }

# variable "api_token" {
#   type = string
#   description = "Proxmox API token value"
# }

variable "ssh_user" {
  type        = string
  description = "Proxmox SSH user. Should be configured on each proxmox host and should have permission to use sudo. sudo is not installed be default on proxmox hosts"
}

variable "ssh_password" {
  type        = string
  description = "Proxmox SSH user password."
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

# Generate a random token to use for nodes joining cluster
resource "random_password" "join_token" {
  length  = 40
  special = false
}

module "k3s-management" {
  source = "../../modules/k3s"

  template_name           = local.template_name
  root_disk_datastore_id  = "local-zfs"
  cloud_init_datastore_id = "local-zfs"
  cluster_name            = "k3s-example"
  # List of static IPs for nodes. If using this input var, it should have 1 IP per proxmox node added to local.node_list
  server_ips     = ["10.1.0.10/23", "10.1.0.11/23", "10.1.0.12/23"]
  server_gateway = "10.1.0.1"
  # List of proxmox nodes to deploy a k3s server node onto. This variable is used to determine the number of server nodes and which hosts to create them on
  proxmox_server_nodes = local.node_list
  join_token           = random_password.join_token.result
  # For this example the server hostname is set to first static IP passed in to the module which will be assigned to the bootstrap node.
  # See k3s module README for notes on recommended method of configuring this
  server_hostname = "10.1.0.10"
  user            = local.vm_ssh_user
  user_password   = local.vm_user_password
  ssh_key         = local.vm_ssh_key
  # Snippet datastore can be any datastore that exists on each proxmox node. This example lists an NFS share that exists on each node
  snippet_datastore = "some-nfs-share"
  cpu_type          = "host"
  root_disk_size    = 25

}

# If DHCP is used instead of static IPs, this can retrieve the IP of the bootstrap node
output "bootstrap_ipv4_address" {
  value = module.k3s-management.bootstrap_ipv4_address
}
