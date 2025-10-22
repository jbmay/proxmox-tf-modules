locals {
  uname      = var.unique_suffix ? lower("${var.name_prefix}-${random_string.uid.result}") : lower(var.name_prefix)
  node_count = length(var.haproxy_nodes)
}

resource "random_string" "uid" {
  length  = 3
  special = false
  lower   = true
  upper   = false
  numeric = true
}

resource "proxmox_virtual_environment_file" "haproxy_user_data_cloud_config" {
  count        = local.node_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.haproxy_nodes[count.index]

  source_raw {
    data = templatefile("${path.module}/userdata-template.tftpl", { user = var.user, user_password = var.user_password, ssh_key = var.ssh_key, dataplane_password = var.dataplane_password, listener_port = var.listener_port, lb_target_ip_list = var.lb_target_ip_list, target_port = var.target_port, keepalived_state = count.index == 0 ? "MASTER" : "BACKUP", keepalived_priority = count.index == 0 ? 200 : 100, virtual_router_id = var.virtual_router_id, lb_vip = var.lb_vip, haproxy_image = var.haproxy_image })

    file_name = "${local.uname}-haproxy-${count.index}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "haproxy_metadata_cloud_config" {
  count        = local.node_count
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.haproxy_nodes[count.index]

  source_raw {
    data = <<-EOF
    #cloud-config
    local-hostname: ${local.uname}-haproxy-${count.index}
    EOF

    file_name = "${local.uname}-haproxy-${count.index}-metadata-cloud-config.yaml"
  }
}

data "proxmox_virtual_environment_vms" "haproxy_template_vms" {
  count = local.node_count
  filter {
    name   = "name"
    regex  = false
    values = [var.template_name]
  }
  filter {
    name   = "node_name"
    regex  = false
    values = [var.haproxy_nodes[count.index]]
  }
}

resource "proxmox_virtual_environment_vm" "haproxy_nodes" {
  count     = local.node_count
  name      = "${local.uname}-haproxy-${count.index}"
  node_name = var.haproxy_nodes[count.index]

  agent {
    enabled = true
  }

  cpu {
    cores = var.haproxy_cpu_cores
    type  = var.cpu_type
    numa  = var.cpu_numa
  }

  memory {
    dedicated = var.haproxy_memory
    floating  = var.haproxy_memory
  }

  clone {
    vm_id        = data.proxmox_virtual_environment_vms.haproxy_template_vms[count.index].vms[0].vm_id
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
        address = var.haproxy_ips == null ? "dhcp" : var.haproxy_ips[count.index]
        gateway = var.network_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.haproxy_user_data_cloud_config[count.index].id
    meta_data_file_id = proxmox_virtual_environment_file.haproxy_metadata_cloud_config[count.index].id
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
