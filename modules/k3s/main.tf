locals {
  uname        = var.unique_suffix ? lower("${var.cluster_name}-${random_string.uid.result}") : lower(var.cluster_name)
  server_count = length(var.proxmox_server_nodes)
  agent_count  = length(var.proxmox_agent_nodes)
}

resource "random_string" "uid" {
  length  = 3
  special = false
  lower   = true
  upper   = false
  numeric = true
}

resource "proxmox_virtual_environment_file" "bootstrap_user_data_cloud_config" {
  count        = var.bootstrap_cluster ? 1 : 0
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_server_nodes[0]

  source_raw {
    data = <<-EOF
    #cloud-config
    prefer_fqdn_over_hostname: false
    users:
      - name: ${var.user}
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        shell: /bin/bash
        hashed_passwd: "${var.user_password}"
        lock_passwd: false
        chpasswd: { expire: False }
        ssh_authorized_keys:
          - ${var.ssh_key}
        ssh_pwauth: True
    runcmd:
        - apt update && apt upgrade -y
        - curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_TOKEN=${var.join_token} sh -s - server --cluster-init --tls-san=${var.server_hostname}
    EOF

    file_name = "${local.uname}-server-${count.index}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "server_user_data_cloud_config" {
  count        = var.bootstrap_cluster ? local.server_count - 1 : local.server_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.bootstrap_cluster ? var.proxmox_server_nodes[count.index + 1] : var.proxmox_server_nodes[count.index]

  source_raw {
    data = <<-EOF
    #cloud-config
    prefer_fqdn_over_hostname: false
    users:
      - name: ${var.user}
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        shell: /bin/bash
        hashed_passwd: "${var.user_password}"
        lock_passwd: false
        chpasswd: { expire: False }
        ssh_authorized_keys:
          - ${var.ssh_key}
        ssh_pwauth: True
    runcmd:
        - apt update && apt upgrade -y
        - curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_TOKEN=${var.join_token} sh -s - server --server https://${var.server_hostname}:6443 --tls-san=${var.server_hostname}
    EOF

    file_name = "${local.uname}-server-${var.bootstrap_cluster ? count.index + 1 : count.index}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "server_metadata_cloud_config" {
  count        = local.server_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_server_nodes[count.index]

  source_raw {
    data = <<-EOF
    #cloud-config
    local-hostname: ${local.uname}-server-${count.index}
    EOF

    file_name = "${local.uname}-server-${count.index}-metadata-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "agent_user_data_cloud_config" {
  count        = local.agent_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_agent_nodes[count.index]

  source_raw {
    data = <<-EOF
    #cloud-config
    prefer_fqdn_over_hostname: false
    users:
      - name: ${var.user}
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        shell: /bin/bash
        hashed_passwd: "${var.user_password}"
        lock_passwd: false
        chpasswd: { expire: False }
        ssh_authorized_keys:
          - ${var.ssh_key}
        ssh_pwauth: True
    runcmd:
        - apt update && apt upgrade -y
        - curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_TOKEN=${var.join_token} sh -s - agent --server https://${var.server_hostname}:6443
    EOF

    file_name = "${local.uname}-agent-${count.index}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "agent_metadata_cloud_config" {
  count        = local.agent_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_agent_nodes[count.index]

  source_raw {
    data = <<-EOF
    #cloud-config
    local-hostname: ${local.uname}-agent-${count.index}
    EOF

    file_name = "${local.uname}-agent-${count.index}-metadata-cloud-config.yaml"
  }
}

data "proxmox_virtual_environment_vms" "server_template_vms" {
  count = local.server_count
  filter {
    name   = "name"
    regex  = false
    values = [var.template_name]
  }
  filter {
    name   = "node_name"
    regex  = false
    values = [var.proxmox_server_nodes[count.index]]
  }
}

data "proxmox_virtual_environment_vms" "agent_template_vms" {
  count = local.agent_count
  filter {
    name   = "name"
    regex  = false
    values = [var.template_name]
  }
  filter {
    name   = "node_name"
    regex  = false
    values = [var.proxmox_agent_nodes[count.index]]
  }
}

resource "proxmox_virtual_environment_vm" "k3s_bootstrap_node" {
  count     = var.bootstrap_cluster ? 1 : 0
  name      = "${local.uname}-server-0"
  node_name = var.proxmox_server_nodes[0]

  agent {
    enabled = true
  }

  cpu {
    cores = var.server_cpu_cores
    type  = var.cpu_type
    numa  = var.cpu_numa
  }

  memory {
    dedicated = var.server_memory
    floating  = var.server_memory
  }

  clone {
    vm_id        = data.proxmox_virtual_environment_vms.server_template_vms[0].vms[0].vm_id
    datastore_id = var.root_disk_datastore_id
    full         = true
  }

  # Settings and size of cloned root volume
  disk {
    datastore_id = var.root_disk_datastore_id
    interface    = var.root_disk_interface
    iothread     = var.root_disk_iothread
    discard      = var.root_disk_discard
    size         = var.root_disk_size
    ssd          = var.root_disk_ssd
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id
    ip_config {
      ipv4 {
        address = var.server_ips != null ? var.server_ips[0] : "dhcp"
        gateway = var.server_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.bootstrap_user_data_cloud_config[0].id
    meta_data_file_id = proxmox_virtual_environment_file.server_metadata_cloud_config[0].id
  }

  network_device {
    bridge   = var.network_device_bridge
    firewall = var.network_device_firewall
    mtu      = var.network_device_mtu
    vlan_id  = var.network_device_vlan_id
  }

  vga {
    memory = var.vga_memory
    type   = var.vga_type
  }
}

resource "proxmox_virtual_environment_vm" "k3s_server_nodes" {
  count     = var.bootstrap_cluster ? local.server_count - 1 : local.server_count
  name      = var.bootstrap_cluster ? "${local.uname}-server-${count.index + 1}" : "${local.uname}-server-${count.index}"
  node_name = var.bootstrap_cluster ? var.proxmox_server_nodes[count.index + 1] : var.proxmox_server_nodes[count.index]

  agent {
    enabled = true
  }

  cpu {
    cores = var.server_cpu_cores
    type  = var.cpu_type
    numa  = var.cpu_numa
  }

  memory {
    dedicated = var.server_memory
    floating  = var.server_memory
  }

  clone {
    vm_id        = var.bootstrap_cluster ? data.proxmox_virtual_environment_vms.server_template_vms[count.index + 1].vms[0].vm_id : data.proxmox_virtual_environment_vms.server_template_vms[count.index].vms[0].vm_id
    datastore_id = var.root_disk_datastore_id
    full         = true
  }

  # Settings and size of cloned root volume
  disk {
    datastore_id = var.root_disk_datastore_id
    interface    = var.root_disk_interface
    iothread     = var.root_disk_iothread
    discard      = var.root_disk_discard
    size         = var.root_disk_size
    ssd          = var.root_disk_ssd
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id
    ip_config {
      ipv4 {
        address = var.server_ips == null ? "dhcp" : var.bootstrap_cluster ? var.server_ips[count.index + 1] : var.server_ips[count.index]
        gateway = var.server_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.server_user_data_cloud_config[count.index].id
    meta_data_file_id = var.bootstrap_cluster ? proxmox_virtual_environment_file.server_metadata_cloud_config[count.index + 1].id : proxmox_virtual_environment_file.server_metadata_cloud_config[count.index].id
  }

  network_device {
    bridge   = var.network_device_bridge
    firewall = var.network_device_firewall
    mtu      = var.network_device_mtu
    vlan_id  = var.network_device_vlan_id
  }

  vga {
    memory = var.vga_memory
    type   = var.vga_type
  }
}

resource "proxmox_virtual_environment_vm" "k3s_agent_nodes" {
  count     = local.agent_count
  name      = "${local.uname}-agent-${count.index}"
  node_name = var.proxmox_agent_nodes[count.index]

  agent {
    enabled = true
  }

  cpu {
    cores = var.agent_cpu_cores
    type  = var.cpu_type
    numa  = var.cpu_numa
  }

  memory {
    dedicated = var.agent_memory
    floating  = var.agent_memory
  }

  clone {
    vm_id        = data.proxmox_virtual_environment_vms.agent_template_vms[count.index].vms[0].vm_id
    datastore_id = var.root_disk_datastore_id
    full         = true
  }

  # Settings and size of cloned root volume
  disk {
    datastore_id = var.root_disk_datastore_id
    interface    = var.root_disk_interface
    iothread     = var.root_disk_iothread
    discard      = var.root_disk_discard
    size         = var.root_disk_size
    ssd          = var.root_disk_ssd
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.agent_user_data_cloud_config[count.index].id
    meta_data_file_id = proxmox_virtual_environment_file.agent_metadata_cloud_config[count.index].id
  }

  network_device {
    bridge   = var.network_device_bridge
    firewall = var.network_device_firewall
    mtu      = var.network_device_mtu
    vlan_id  = var.network_device_vlan_id
  }

  vga {
    memory = var.vga_memory
    type   = var.vga_type
  }
}
