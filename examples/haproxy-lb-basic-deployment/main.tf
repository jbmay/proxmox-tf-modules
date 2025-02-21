locals {
  vm_ssh_user = "example-vm-user"
  vm_ssh_key  = "ssh public key for vm access"
  # password `password` hashed with command `mkpasswd -m sha-512 -s`
  vm_user_password  = "$6$lYn1N2zlfWxOnRrC$bSBBiEFdphiF.uG7Md0NsYerF0zfqREKI/SJsxG.0LJIZRRVwwsf.NpG9lY8lm09r5yFbSDlFXpodXmVqWzxR0"
  haproxy_node_list = ["pve0", "pve1"]
  # Proxmox VM template that exists on each proxmox node you want to deploy a VM onto. Should have qemu-guest-agent installed and configured to run
  lb_template_name = "ubuntu-docker-2204-template.v1" # ubuntu server with docker preinstalled
  lb_vip           = "10.1.0.20/23"
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
    key       = "haproxy-lb-basic-deployment/terraform.tfstate"
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

# This example shows configuring HAProxy with 2 nodes each deployed to a different Proxmox node, and they are configured to load balance traffic between 4 target IPs
# Note that the listener_port and target_port are independent and don't need to be the same value
module "k3s_api_lb" {
  # source ref using a git tag on public github repository
  # source = git::https://github.com/jbmay/proxmox-tf-modules.git//modules/haproxy-lb?ref=v0.2.0
  # example local ref to module in same repo for testing changes
  source = "../../modules/haproxy-lb"

  user                    = local.vm_ssh_user
  user_password           = local.vm_user_password
  dataplane_password      = "example-dataplane-password"
  ssh_key                 = local.vm_ssh_key
  listener_port           = 443                                              # port that haproxy nodes accept traffic on
  target_port             = 8443                                             # port that target IPs accept traffic on
  lb_target_ip_list       = ["10.1.1.1", "10.1.1.2", "10.1.1.3", "10.1.1.4"] # List of IP addresses running the service listening on the target_port to be load balanced
  lb_vip                  = local.lb_vip
  virtual_router_id       = 97 # This variable is optional unless another VRRP cluster is already using id 51 on your network. We are arbitrarily setting it to 97
  template_name           = local.lb_template_name
  root_disk_datastore_id  = "local-zfs"
  cloud_init_datastore_id = "local-zfs"
  name_prefix             = "k3s-mgmt"
  haproxy_nodes           = local.haproxy_node_list
  snippet_datastore       = "some-nfs-share"
  cpu_type                = "host"
  root_disk_size          = 10

}
