# k3s module

Module for provisioning k3s clusters in proxmox. Currently this module relies on having an internet connection to grab the k3s install script and to pull k3s dependencies. In the future it may be updated to support disconnected installations as well when paired with images built for disconnected installs.

Uses bpg proxmox provider.

# Assumptions
- Currently expects to clone a Debian/Ubuntu proxmox template that has the qemu-guest-agent already installed. Tested with template built on Ubuntu server minimal cloud image version 22.04 with qemu-guest-agent preconfigured
- Currently expects network interface to be preconfigured on template
- Relies on having SSH access to proxmox nodes in order to create snippets used for configuring cloud-init userdata and metadata
- Expects the same template to be available on each Proxmox node for VM cloning

# Known issues and limitations
- Currently there seems to be a bug with the bpg provider as of version 0.70.1 when attempting to expand the root volume after cloning. This means currently it has only been tested to work when deploying with the root_disk_size set to the same size as the template being cloned
  - This issue was encountered with version 0.70.1 of the module, version 1.9.0 of tofu, and proxmox version 7.4-17
- Currently only deploys with a root disk and doesn't configure additional data volumes
- Currently only deploys server nodes, no dedicated agent nodes
- This module can be used to bootstrap new clusters and join nodes to existing clusters, but it does not automatically handle nodes being removed from the cluster or cluster upgrades. Without using other tooling for cluster upgrades, the upgrade path using only this module would be to deploy a new set of upgraded nodes, join them to your cluster, and then manually cordon and drain the old nodes. Then once workloads have migrated to the new nodes, you could destroy the old node VMs with a tofu/terraform destroy
- Currently doesn't grab a specific version of k3s. This will be changed soon