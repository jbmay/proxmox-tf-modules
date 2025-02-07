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
  - Related GitHub issues [781](https://github.com/bpg/terraform-provider-proxmox/issues/781), [360](https://github.com/bpg/terraform-provider-proxmox/issues/360), [1747](https://github.com/bpg/terraform-provider-proxmox/issues/1747)
  - Workaround for this issue found and documented below
- Currently only deploys with a root disk and doesn't configure additional data volumes
- Currently only deploys server nodes, no dedicated agent nodes
- This module can be used to bootstrap new clusters and join nodes to existing clusters, but it does not automatically handle nodes being removed from the cluster or cluster upgrades. Without using other tooling for cluster upgrades, the upgrade path using only this module would be to deploy a new set of upgraded nodes, join them to your cluster, and then manually cordon and drain the old nodes. Then once workloads have migrated to the new nodes, you could destroy the old node VMs with a tofu/terraform destroy
- If the template being cloned has any settings configured that the VM definitions in this module don't configure, an initial deploy will work fine but subsequent deploys will want to revert those settings from the template to match the defaults that the provider uses. This will appear as terraform/tofu wanting to change settings to null or default values if the provider has any.
  - If there are any default cloud-init settings on the template for configuring a user, password, or ssh key then a subsequent apply will want to destroy and recreate the VMs because cloud-init changes force a recreation. It is recommended to remove these settings from the templates being used with this module

# Workaround for disk expansion bug
Discovered that the bug related to expanding disks can be worked around by manually rebooting VMs after applying with updated disk size, followed by a second apply.

Steps:
- Deploy from template using the template disk size for the initial deploy to ensure you get a clean deploy and state
- After VMs come up and cluster is operational, update disk size to new larger size
- Run tofu apply
  - You will receive an error from tofu saying `error waiting for VM disk resize: All attempts fail:` for each disk attempting to resize
  - If you check the proxmox UI you will see pending changes on the VMs showing the current disk size already being the updated size and the pending size being the original
  ![alt text](../../docs/images/pending_disk_size.png)
  - Shutdown and restart (actually shutdown, don't just reboot or proxmox won't apply the pending changes) the VMs one at a time and make sure you wait for k3s to come back up and become ready in between each VM shutdown
  - At this point proxmox will show the old size in the GUI still, but the disks in the VM should be the new updated size
- Run another tofu apply
  - You will see the same error as before, but now if you look in the GUI all the VMs should show the updated size
- Subsequent applies should show no resources needing to be updated which indicates the tofu state matches the deployed infrastructure

Depending on your VMs, you may need to manually resize volumes and file systems in the OS after expanding the disks.

This might even work for the initial VM creation, but I am uncertain if the tofu error is hit before it finishes setting everything else up for the VMs and haven't tested it enough to say with certainty.