# haproxy-lb module

Module for provisioning HAProxy TCP load balancers in proxmox. This module can be used to create high availability HAProxy load balancers that automatically failover if the current HAProxy primary fails. It can deploy as many HA proxy VMs as you desire and configures one as the primary and the rest as equally weighted backups using keepalived and a virtual IP.

The load balancer VMs that are created by this module currently run HAProxy in a docker container and keepalived is installed as an OS package. Newer versions of HAProxy are only distributed as container images or source code that you have to build yourself, so I decided to use the container image for HAProxy for simplicity.

Currently this module relies on having an internet connection to pull the HAProxy image and install keepalived. In the future it may be updated to support disconnected installations as well when paired with VM images built for disconnected installs.

Uses bpg proxmox provider.

# Assumptions
- Template cloned for creating HAProxy VMs already has docker and quem-guest-agent installed
- Template cloned is Debian/Ubuntu based
- The template is available on each Proxmox node that a VM is being deployed to for VM cloning
- You have a static IP available to assign as the virtual IP for the load balancer cluster

# Configuration notes

## Node count and location
Since Proxmox requires choosing a specific node to create a VM on, this module relies on passing lists of nodes to control the count and location of HAProxy VMs. For example setting `haproxy_nodes = ["pve0", "pve1", "pve2"]` would create 1 HAProxy VM on each of the listed proxmox hosts. Setting `haproxy_nodes = ["pve0", "pve0", "pve0"]` would instead create 3 HAProxy VMs all on the proxmox host named `pve0`. It is a little clunky compared to just passing in a count, but it is a proxmox-ism.

For high availability you should deploy at least 2 load balancer nodes and they should be on different host machines. This allows the service that traffic is being load balanced for to still be accessible if a HAProxy node goes down for some reason such as a proxmox host going down for maintenance.

## Triggering Failover
Currently this module configures keepalived to use the HAProxy monitor-uri to check if HAProxy is healthy. I am uncertain if there is a better way to check HAProxy health such as using data from the stats socket.

Example healthcheck using stats socket found on HAProxy guide. Would need equivalent using the http stats endpoint since HAProxy is running in docker
```
script 'echo "show info" | socat /var/run/haproxy.sock stdio | grep "Stopping: 0"' # haproxy runs in a container so we can't just check the process is running
```

Another possibility would be to simply check that the HAProxy docker container is running. I don't think this is as good as checking the HAProxy monitor-uri though but am documenting it as an alternative to the implemented solution.
```
[ "$(/usr/bin/docker inspect --format='{{.State.Status}}' haproxy 2>/dev/null)" == "running" ] && exit 0 || exit 1
```

## keepalived settings
This module configures keepalived for HAProxy failover. This requires providing a static IP to input variable `lb_vip` for keepalived to use as a virtual IP which is what enables traffic to automatically start routing to a different HAProxy node if the current primary becomes unavailable.

This also requires settings a virtual router id which is how the keepalived nodes identify themselves to eachother and distinguish themselves from other VRRP clusters on your network. By default the `virtual_router_id` input var for this module is set to `51`. This value must be unique from any other VRRP clusters on your network, so if you use this module multiple times for different services or if you have other resources on your network using VRRP, you need to change this value and ensure it doesn't collide with other values in use.

Currently this module configures keepalived to use multicast instead of configuring unicast. This allows it to work without each keepalived node needing to know the IPs of the other nodes and makes the module easier to configure when using DHCP instead of a set of static IPs for the HAProxy nodes.

## Editing HAProxy config post install
This module doesn't expose a ton of configuration options for HAProxy and is primarily intended to have an easy way to quickly deploy TCP load balancers. For different configuration needs beyond what the module configures out of the box, it configures HAProxy with the dataplane API enabled. This enables reconfiguring HAProxy via an API if desired instead of needing to SSH and edit the HAProxy config file directly. That is why the `dataplane_password` is required when deploying this module.

Currently this is always enabled, but in the future it may be put behind a toggle so it can be disabled for users that don't want to have an API that allows editing HAProxy settings.

# Known issues and limitations
- If the template being cloned has any settings configured that the VM settings in this module don't configure, an initial deploy will work fine but subsequent deploys will want to revert those settings from the template to match the defaults that the provider uses. This will appear as terraform/tofu wanting to change settings to null or default values if the provider has any.
  - If there are any default cloud-init settings on the template for configuring a user, password, or ssh key then a subsequent apply will want to destroy and recreate the VMs because cloud-init changes force a recreation. It is recommended to remove these settings from the templates being used with this module
- Currently only provisions HAProxy as a TCP load balancer. Does not expose settings for configuring HTTP load balancing
  - Currently only supports configuring a single listener port and target port for the load balancer
