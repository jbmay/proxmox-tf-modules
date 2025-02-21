output "server_node_ipv4_addresses" {
  value = var.bootstrap_cluster ? concat([proxmox_virtual_environment_vm.k3s_bootstrap_node[0].ipv4_addresses[1][0]], [for server in proxmox_virtual_environment_vm.k3s_server_nodes : server.ipv4_addresses[1][0]]) : [for server in proxmox_virtual_environment_vm.k3s_server_nodes : server.ipv4_addresses[1][0]]
}