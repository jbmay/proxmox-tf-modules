output "bootstrap_ipv4_address" {
  value = proxmox_virtual_environment_vm.k3s_bootstrap_node[0].ipv4_addresses[1][0]
}