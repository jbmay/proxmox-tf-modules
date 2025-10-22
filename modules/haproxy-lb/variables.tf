## cloud-init settings

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

variable "dataplane_password" {
  description = "Password to set for haproxy dataplane API"
  type        = string
}

variable "haproxy_image" {
  description = "What container image and version of haproxy to use?"
  type        = string
  default     = "haproxytech/haproxy-alpine-quic:3.0"
}

variable "listener_port" {
  description = "The port for the LB to listen for TCP connections on."
  type        = number
}

variable "target_port" {
  description = "The port for the LB to send traffic to on target servers."
  type        = number
}

variable "lb_target_ip_list" {
  description = "List of IPs for load balancer to balance traffic between."
  type        = list(string)
}

variable "virtual_router_id" {
  description = "Unique VRRP virtual router id. If you have multiple VRRP clusters on your network, this can't use an id already in use."
  type        = number
  default     = 51
}

variable "lb_vip" {
  description = "Virtual IP for load balancer in cidr notation. ex 192.168.1.27/24"
  type        = string
}

## VM Settings
variable "template_name" {
  description = "Name of proxmox template to clone when creating haproxy node VMs"
  type        = string
}

variable "root_disk_datastore_id" {
  description = "Datastore to clone root VM disk to"
  type        = string
}

variable "root_disk_size" {
  description = "Size in GB to set root disk to. Must be equal or larger than the cloned disk"
  type        = number
  default     = 10
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

variable "name_prefix" {
  description = "The base name for resources that are created"
  type        = string
}

variable "haproxy_ips" {
  description = "List of static IPs in CIDR notation for haproxy nodes. If set, should be same size as var.haproxy_nodes so one IP is available per VM"
  type        = list(string)
  default     = null
}

variable "network_gateway" {
  description = "IP gateway for VMs. Should be null if using DHCP, and set to the correct gateway if setting static IPs"
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "List of DNS servers to set for VMs. Optional if using DHCP"
  type        = list(string)
  default     = null
}

variable "haproxy_nodes" {
  description = "List of proxmox nodes to deploy haproxy nodes to. 1 haproxy VM per proxmox node will be created."
  type        = list(string)
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

variable "haproxy_cpu_cores" {
  description = "Cores for each haproxy node"
  type        = number
  default     = 1
}

variable "haproxy_memory" {
  description = "Memory for each haproxy node in MiB"
  type        = number
  default     = 2 * 1024
}

variable "network_device_vlan_id" {
  description = "VLAN ID to assign to network device"
  type        = string
  default     = null
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
