# k3s-example-deployment
This example deployment shows a possible configuration using the k3s module to deploy a k3s cluster in proxmox and putting a TCP loadbalancer in front of the kubernetes API using the haproxy-lb module. It configures the k3s nodes to use the loadbalancer VIP as the server hostname so they will register through the load balancer instead of connecting directly to a single server node like the basic example.

The example currently shows how you could use the modules to deploy 3 server nodes and 3 haproxy nodes with 1 server node and 1 haproxy VM running on each of 3 different proxmox hosts.

## Testing failover
You can connect to the host of the master HAProxy VM and stop the HAProxy docker container to test one of the backups picking up the VIP.

After your k3d cluster and HAProxy nodes are all up and healthy, grab the kubeconfig from one of the server nodes and copy it to a different machine. Change the server hostname from `127.0.0.1` to whatever you set the `lb_vip` to and test to make sure you can connect to your cluster through HAProxy by running `kubectl get nodes` after changing that hostname. If you copied this example, you should see the 3 server nodes have joined the cluster and are ready to have workloads scheduled.

Connect to whichever HAProxy host currently has the VIP assigned to it and run `docker stop haproxy`. After a few seconds you should see one of the HAProxy backups pickup the VIP. On the machine you copied the kubeconfig to in the previous step rerun `kubectl get nodes` and you should again see the nodes and there should be nothing indicating that your connection is hitting a different HAProxy node.

Reconnect to the HAProxy node that had the HAProxy container stopped and run `docker start haproxy`. After a few seconds you should see the VIP moved back to that node.

## DNS
This can be extended further by settings a DNS entry that will resolve the lb_vip for a hostname that you want to use for the kubernetes API. Based on this example, you would set something like `kube-api.yourhostname.com` to resolve `10.1.0.20` and set `server_hostname` on the k3s module to `kube-api.yourhostname.com` instead of `10.1.0.20` like it currently does.

A future example will include doing this with terraform, but you can just configure the DNS entry for the kube-api domain before deploying if you would like to use a hostname.
