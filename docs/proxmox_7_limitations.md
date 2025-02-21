# Proxmox 7 (and older) limitations

- There is an issue with the bpg provider as of version 0.70.1 when using Proxmox versions 7.x while attempting to expand the root volume after cloning related to the provider using the newer Proxmox 8.x API.
  - This issue was encountered with version 0.70.1 of the module, version 1.9.0 of tofu, and proxmox version 7.4-17
  - Workaround for this issue found and documented below for Proxmox 7.x users
  - Update: This issue is apparently specific to Proxmox versions before 8.x [according to the bpg provider dev](https://github.com/bpg/terraform-provider-proxmox/issues/1747#issuecomment-2641864871). If using Proxmox 8 or newer, this shouldn't be an issue

## Workaround for disk expansion bug for users still on proxmox 7.x
Update: This issue is apparently specific to Proxmox versions before 8.x [according to the provider dev](https://github.com/bpg/terraform-provider-proxmox/issues/1747#issuecomment-2641864871). If using Proxmox 8 or newer, this shouldn't be an issue.

Discovered that the bug related to expanding disks can be worked around by manually rebooting VMs after applying with updated disk size, followed by a second apply.

Steps:
- Deploy from template using the template disk size for the initial deploy to ensure you get a clean deploy and state
- After VMs come up and cluster is operational, update disk size to new larger size
- Run tofu apply
  - You will receive an error from tofu saying `error waiting for VM disk resize: All attempts fail:` for each disk attempting to resize
  - If you check the proxmox UI you will see pending changes on the VMs showing the current disk size already being the updated size and the pending size being the original
  ![alt text](./docs/images/pending_disk_size.png)
  - Shutdown and restart (actually shutdown, don't just reboot or proxmox won't apply the pending changes) the VMs one at a time and make sure you wait for k3s to come back up and become ready in between each VM shutdown
  - At this point proxmox will show the old size in the GUI still, but the disks in the VM should be the new updated size
- Run another tofu apply
  - You will see the same error as before, but now if you look in the GUI all the VMs should show the updated size
- Subsequent applies should show no resources needing to be updated which indicates the tofu state matches the deployed infrastructure

Depending on your specific VM OS configuration, you may need to manually resize volumes and file systems in the OS after expanding the disks.