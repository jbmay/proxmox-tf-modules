locals {
  uname = var.unique_suffix ? lower("${var.name_prefix}-${random_string.uid.result}") : lower(var.name_prefix)
}

resource "random_string" "uid" {
  length  = 3
  special = false
  lower   = true
  upper   = false
  numeric = true
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_node

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
    write_files:
      - path: /usr/local/bin/provision-data-disks.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          COUNT="${length(var.data_disks)}"
          if [[ "$COUNT" -le 0 ]]; then
            echo "No data disks to format."
            exit 0
          fi
          IFS=',' read -r -a MOUNTS <<< "${join(",", [for d in var.data_disks : d.mount_location])}"

          disks=()
          start_ord=$(printf '%d' "'b")   # ASCII of 'b'
          for ((i=0; i<COUNT; i++)); do
            letter=$(printf "\\$(printf '%03o' $((start_ord + i)))")
            disks+=("/dev/sd$${letter}")
          done

          idx=1
          for ((i=0; i<COUNT; i++)); do
            d="$${disks[$i]}"

            # choose mount path:
            # - if provided value is "/mnt/data", use "/mnt/data$idx"
            # - else use provided value as-is
            provided="$${MOUNTS[$i]:-/mnt/data}"
            if [[ "$provided" == "/mnt/data" ]]; then
              mnt="/mnt/data$${idx}"
            else
              mnt="$provided"
            fi
            idx=$((idx+1))

            echo "Configuring $d -> $mnt"

            # wait for device node
            for _ in {1..60}; do [[ -b "$d" ]] && break; sleep 1; done
            [[ -b "$d" ]] || { echo "Device $d not found"; exit 1; }

            # create GPT + one partition (whole disk)
            parted -s "$d" mklabel gpt
            parted -s "$d" mkpart primary ext4 0% 100%
            partprobe "$d"
            p="$${d}1"
            
            # wait for partition
            for _ in {1..60}; do [[ -b "$p" ]] && break; sleep 1; done
            [[ -b "$p" ]] || { echo "Partition $p not found"; exit 1; }

            # make filesystem
            mkfs.ext4 $p

            # ensure mount point exists
            mkdir -p "$mnt"

            # add to fstab by UUID (idempotent)
            uuid="$(blkid -s UUID -o value "$p")"
            grep -qE "^UUID=$${uuid}[[:space:]]" /etc/fstab || \
              echo "UUID=$${uuid}  $${mnt}  ext4  defaults,nofail  0  2" >> /etc/fstab
          done

          # Mount all
          systemctl daemon-reload || true
          mount -a
    runcmd:
        - |
          DISTRO=$( cat /etc/os-release | tr [:upper:] [:lower:] | grep -Poi '(ubuntu|rhel)' | uniq )
          if [ $DISTRO == ubuntu]; then
            apt update && apt upgrade -y
          else
            dnf update -y
          fi
        - [bash, /usr/local/bin/provision-data-disks.sh]

    EOF

    file_name = "${local.uname}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "metadata_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = var.proxmox_node

  source_raw {
    data = <<-EOF
    #cloud-config
    local-hostname: ${local.uname}
    EOF

    file_name = "${local.uname}-metadata-cloud-config.yaml"
  }
}

data "proxmox_virtual_environment_vms" "template_vm" {
  filter {
    name   = "name"
    regex  = false
    values = [var.template_name]
  }
  filter {
    name   = "node_name"
    regex  = false
    values = [var.proxmox_node]
  }
}

resource "proxmox_virtual_environment_vm" "generic_vm" {
  name      = local.uname
  node_name = var.proxmox_node
  tags      = var.tags

  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
    numa  = var.cpu_numa
  }

  memory {
    dedicated = var.memory
    floating  = var.memory
  }

  clone {
    vm_id        = data.proxmox_virtual_environment_vms.template_vm.vms[0].vm_id
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

  dynamic "disk" {
    for_each = var.data_disks
    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size
      iothread     = disk.value.iothread
      ssd          = disk.value.ssd
      discard      = disk.value.discard
    }
  } 

  initialization {
    datastore_id = var.cloud_init_datastore_id
    ip_config {
      ipv4 {
        address = var.static_ip != null ? var.static_ip : "dhcp"
        gateway = var.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
    meta_data_file_id = proxmox_virtual_environment_file.metadata_cloud_config.id
  }

  network_device {
    bridge   = var.network_device_bridge
    firewall = var.network_device_firewall
    mtu      = var.network_device_mtu
  }

  vga {
    memory = var.vga_memory
    type   = var.vga_type
  }
}
