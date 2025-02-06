locals {
  uname = var.unique_suffix ? lower("${var.cluster_name}-${random_string.uid.result}") : lower(var.cluster_name)
  server_count = length(var.proxmox_server_nodes)
  agent_count = length(var.proxmox_agent_nodes)
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
        - apt update
        - curl -sfL https://get.k3s.io | K3S_TOKEN=${var.join_token} sh -s - server --cluster-init --tls-san=${var.cluster_tls_san}
    EOF

    file_name = "${local.uname}-server-${count.index}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "server_user_data_cloud_config" {
  count        = var.bootstrap_cluster ? local.server_count - 1 : local.server_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name = var.bootstrap_cluster ? var.proxmox_server_nodes[count.index + 1] : var.proxmox_server_nodes[count.index]

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
        - apt update
        - curl -sfL https://get.k3s.io | K3S_TOKEN=${var.join_token} sh -s - server --server https://${var.cluster_tls_san}:6443 --tls-san=${var.cluster_tls_san}
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
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.root_disk_size
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
    meta_data_file_id  = proxmox_virtual_environment_file.server_metadata_cloud_config[0].id
  }
}

resource "proxmox_virtual_environment_vm" "k3s_server_nodes" {
  count        = var.bootstrap_cluster ? local.server_count - 1 : local.server_count
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
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.root_disk_size
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
    meta_data_file_id  = var.bootstrap_cluster ? proxmox_virtual_environment_file.server_metadata_cloud_config[count.index + 1].id : proxmox_virtual_environment_file.server_metadata_cloud_config[count.index].id
  }
}

# output "vm_ipv4_address" {
#   value = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses[1][0]
# }
