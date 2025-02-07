## k3s settings

variable "k3s_version" {
  description = "What version of k3s to install?"
  type        = string
  default     = "v1.31.5+k3s1"
}

## VM Settings
variable "template_name" {
  description = "Name of proxmox template to clone when creating k3s node VMs"
  type        = string
}

variable "root_disk_datastore_id" {
  description = "Datastore to clone root VM disk to"
  type        = string
}

variable "root_disk_size" {
  description = "Size in GB to set root disk to. Must be equal or larger than the cloned disk"
  type        = number
  default     = 25
}

variable "root_disk_interface" {
  description = "What interface type for root disk? Defaults to scsi0"
  type        = string
  default     = "scsi0"
}

variable "root_disk_iothread" {
  description = "Should iothreads be used for this disk?"
  type        = bool
  default     = true
}

variable "root_disk_ssd" {
  description = "Should ssd emulation be used for the disk? This is not supported for VirtIO Block drives"
  type        = bool
  default     = true
}

variable "root_disk_discard" {
  description = "Should discard/trim requests be passed to underlying storage? Turn off if underlying storage doesn't support this."
  type        = string
  default     = "on"
}

variable "cloud_init_datastore_id" {
  description = "Datastore to create cloud-init disk on"
  type        = string
}

variable "unique_suffix" {
  description = "Generate unique suffix for resource names"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "The base name of the k3s cluster"
  type        = string
}

variable "server_ips" {
  description = "List of static IPs in CIDR notation for server nodes. If set, should be same size as var.proxmox_server_nodes so one IP is available per server"
  type        = list(string)
  default     = null
}

variable "server_gateway" {
  description = "IP gateway for servers. Should be null if using DHCP, and set to the correct gateway if setting static IPs"
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "List of DNS servers to set for VMs. Optional if using DHCP"
  type        = list(string)
  default     = null
}

variable "proxmox_server_nodes" {
  description = "List of proxmox nodes to deploy server nodes to. 1 server node VM per proxmox node will be created."
  type        = list(string)
}

variable "proxmox_agent_nodes" {
  description = "List of proxmox nodes to deploy agent nodes to. 1 agent node VM per proxmox node will be created."
  type        = list(string)
  default     = []
}

variable "bootstrap_cluster" {
  description = "Should cluster be bootstrapped? Set to true if creating a new cluster, set to false if joining nodes to existing cluster."
  type        = bool
  default     = true
}

variable "join_token" {
  description = "Secret token for nodes to use to join the cluster"
  type        = string
}

variable "cluster_tls_san" {
  description = "Fixed IP or hostname to add to cert SANs for kube API"
  type        = string
}

variable "user" {
  description = "VM username to be created"
  type        = string
}

variable "user_password" {
  description = "Password to set for VM user"
  type        = string
  default     = ""
}

variable "ssh_key" {
  description = "SSH public key for VM user"
  type        = string
}

variable "snippet_datastore" {
  description = "Proxmox storage to store cloud-init snippets"
  type        = string
}

variable "cpu_type" {
  description = "CPU type to set for nodes"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "cpu_numa" {
  description = "Enable NUMA for nodes?"
  type        = bool
  default     = false
}

variable "server_cpu_cores" {
  description = "Cores for each server node"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "Memory for each node"
  type        = number
  default     = 4 * 1024
}

variable "network_device_bridge" {
  description = "Which network bridge to use for the VM network interface. Defaults to vmbr1 since I use vmbr0 for management devices and vmbr1 for my default VM subnet"
  type        = string
  default     = "vmbr1"
}

variable "network_device_firewall" {
  description = "Should firewall rules be used?"
  type        = bool
  default     = true
}

variable "network_device_mtu" {
  description = "MTU for the VM network interface. Defaults to 1 so it is the same as the bridge"
  type        = number
  default     = 1
}

variable "vga_type" {
  description = "Type of VGA. Defaults to serial0 for cloud images"
  type        = string
  default     = "serial0"
}

variable "vga_memory" {
  description = "Memory for VGA"
  type        = number
  default     = 16
}
