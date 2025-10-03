## VM Settings
variable "name_prefix" {
  description = "Prefix to use when naming resources being generated"
  type        = string
}

variable "tags" {
  description = "Tags to add to the VM in Proxmox"
  type        = list(string)
  default     = null
}

variable "template_name" {
  description = "Name of proxmox template to clone when creating VM"
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

variable "data_disks" {
  description = "List of objects for adding data disks to the VM. See the description of the root_disk_* vars for what each of these do."
  type = list(object({
    datastore_id = string
    interface = string
    size = number
    iothread = optional(bool, true)
    ssd = optional(bool, true)
    discard = optional(string, "on")
    mount_location = optional(string, "/mnt/data")
  }))
  validation {
    condition = alltrue([
      for s in var.data_disks : contains(["on", "ignore"], s.discard)
    ])
    error_message = "Discard expected to be set to either 'on' or 'ignore'."
  }
  default = []
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

variable "static_ip" {
  description = "Static IP in CIDR notation for VM"
  type        = string
  default     = null
}

variable "gateway" {
  description = "IP gateway for VM. Should be null if using DHCP, and set to the correct gateway if setting static IP"
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "List of DNS servers to set for VMs. Optional if using DHCP"
  type        = list(string)
  default     = null
}

variable "proxmox_node" {
  description = "Proxmox node to deploy VM to"
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

variable "cpu_cores" {
  description = "Cores for VM"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory for VM"
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
