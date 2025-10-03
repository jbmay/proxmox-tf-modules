# generic-vm module

Module for provisioning VMs in proxmox from proxmox templates. Simple module that fills in all of the boilerplate that always needs configured when provisioning a VM and templates out fields that should be customizable. Runs an apt update and upgrade during cloud-init.

Uses bpg proxmox provider.

# Assumptions
- Currently expects to clone a Debian/Ubuntu proxmox template that has the qemu-guest-agent already installed. Tested with template built on Ubuntu server minimal cloud image version 22.04 with qemu-guest-agent preconfigured
- Relies on having SSH access to proxmox nodes in order to create snippets used for configuring cloud-init userdata and metadata
- The template must be available on the Proxmox node the VM is being deployed to

# Configuration notes
- Currently just clones a template, configures a user via cloud init, and updates software already installed via apt
  - TODO: Add support for customizing cloud-init and/or overriding the default cloud-init file with a custom one

# Known issues and limitations
- Currently only deploys with a root disk and doesn't configure additional data volumes
- If the template being cloned has any settings configured that the VM definitions in this module don't configure, an initial deploy will work fine but subsequent deploys will want to revert those settings from the template to match the defaults that the provider uses. This will appear as terraform/tofu wanting to change settings to null or default values if the provider has any.
  - If there are any default cloud-init settings on the template for configuring a user, password, or ssh key then a subsequent apply will want to destroy and recreate the VMs because cloud-init changes force a recreation. It is recommended to remove these settings from the templates being used with this module
