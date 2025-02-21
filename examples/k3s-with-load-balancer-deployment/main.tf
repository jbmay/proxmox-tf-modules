locals {
  vm_ssh_user = "example-vm-user"
  vm_ssh_key  = "ssh public key for vm access"
  # password `password` hashed with command `mkpasswd -m sha-512 -s`
  vm_user_password = "$6$lYn1N2zlfWxOnRrC$bSBBiEFdphiF.uG7Md0NsYerF0zfqREKI/SJsxG.0LJIZRRVwwsf.NpG9lY8lm09r5yFbSDlFXpodXmVqWzxR0"
  server_node_list = ["pve0", "pve1", "pve2"]
  server_ip_list   = ["10.1.0.10/23", "10.1.0.11/23", "10.1.0.12/23"]
  # Proxmox VM templates that exists on each proxmox node you want to deploy a k3s node onto. Should have qemu-guest-agent installed and configured to run
  k3s_template_name = "ubuntu-server-2204-base-template.v2" # ubuntu server minimal template
  lb_template_name  = "ubuntu-docker-2204-template.v1"      # ubuntu server with docker preinstalled
  lb_vip            = "10.1.0.20/23"
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
  # source ref using a git tag on public github repository
  # source = git::https://github.com/jbmay/proxmox-tf-modules.git//modules/k3s?ref=v0.2.0
  # example local ref to module in same repo for testing changes
  source = "../../modules/k3s"

  template_name           = local.k3s_template_name
  root_disk_datastore_id  = "local-zfs"
  cloud_init_datastore_id = "local-zfs"
  cluster_name            = "k3s-example"
  # List of static IPs for server nodes. If using this input var, it should have 1 IP per proxmox node added to local.server_node_list
  server_ips     = ["10.1.0.10/23", "10.1.0.11/23", "10.1.0.12/23"]
  server_gateway = "10.1.0.1"
  # List of proxmox nodes to deploy a k3s server node onto. This variable is used to determine the number of server nodes and which hosts to create them on
  proxmox_server_nodes = local.server_node_list
  join_token           = random_password.join_token.result
  # Setting server hostname to the virtual IP that will be assigned to our TCP load balancer. The regex is being used to remove the cidr from the end of the lb_vip value.
  server_hostname = regex("^(\\d+\\.\\d+\\.\\d+\\.\\d+)", local.lb_vip)[0]
  user            = local.vm_ssh_user
  user_password   = local.vm_user_password
  ssh_key         = local.vm_ssh_key
  # Snippet datastore can be any datastore that exists on each proxmox node. This example lists an NFS share that exists on each node
  snippet_datastore = "some-nfs-share"
  cpu_type          = "host"
  root_disk_size    = 25

}

# Print out list of server node IPs. This is useful if using DHCP for node IP assignment or when passing the IPs to different resources
output "server_node_ipv4_addresses" {
  value = module.k3s-management.server_node_ipv4_addresses
}

# This example deploys an HAProxy node on the same set of Proxmox nodes that k3s server nodes are being deployed to. The server list for the load balancer module could be a subset or a completely different set of nodes than the k3s server nodes.
# Note that the lb_target_ip_list is being set to a terraform output from the k3s module that contains a list of the server node IPs
module "k3s_api_lb" {
  # source ref using a git tag on public github repository
  # source = git::https://github.com/jbmay/proxmox-tf-modules.git//modules/haproxy-lb?ref=v0.1.4
  # example local ref to module in same repo for testing changes
  source = "../../modules/haproxy-lb"

  user                    = local.vm_ssh_user
  user_password           = local.vm_user_password
  dataplane_password      = "example-dataplane-password"
  ssh_key                 = local.vm_ssh_key
  listener_port           = 6443
  target_port             = 6443
  lb_target_ip_list       = module.k3s-management.server_node_ipv4_addresses
  lb_vip                  = local.lb_vip
  template_name           = local.lb_template_name
  root_disk_datastore_id  = "local-zfs"
  cloud_init_datastore_id = "local-zfs"
  name_prefix             = "k3s-mgmt"
  haproxy_nodes           = local.server_node_list
  snippet_datastore       = "some-nfs-share"
  cpu_type                = "host"
  root_disk_size          = 10

}