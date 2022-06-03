# Document

## OCP 4.6.X and 4.8.X multiple and single master installation
**Warning: `Single master` cluster only supported by ocp version 4.8 and later, and we only do testing on version `4.8.21`**

## Requirements

|  Node   | Fuction  |  OS | Resources |
|  ----  | ----  | ---- |  ---- |
| preparation  | internet accessible, download offline resources | CentOS8.4 | 4C, 8G |
| bastion  | cluster bastion, no internet | CentOS8.4 | 8C, 8G |
| bootstrap | cluster bootstrap, no internet | RHCOS | 8C, 16G |
| master  | cluster master, no internet | RHCOS | 8C, 16G |
| worker  | cluster worker, no internet | RHCOS | 8C, 16G |

## Usage


### On preparation node, action

get `pull-secret.txt` from https://console.redhat.com/openshift/install/pull-secret, save it as `/tmp/pull-secret.txt`

clone this repo to preparation node, modify `./inventory/ocp46.inv`.
The marjor goal to update the  `./inventory/ocp46.inv` is:
- Decide the version of `ocp` you plan to adopt
```
OCP_VERSION="4.8"
OCP_RELEASE="4.8.21"
```

then run

```
./prepare.sh prepare
```

there will be `/ocp4-workspace` folder generated, package it

```
tar -cf ocp4-workspace.tar /ocp4-workspace 
```

copy it to your portable device

**Warning: You should do the upper steps on a abroad machine(maybe with fyre) before you go to the customers office, since it will fetch images from Redhat, depends the bandwidth of customers office to abroad host, it will cost several housrs or more.**

### On bastion node

create bastion node using CentOS8.4, upload the `ocp4-workspace.tar` to your bastion node, execute

```
tar -xf ./ocp4-workspace.tar -C /
```

Before run the script, 
- You need disable the `selinux` and reboot the node
`vim /etc/selinux/config`
Found and set
`SELINUX=disabled`
then
`reboot` the node

- Add one more hard disk and make sure its name is same as `volume_selector` in `inventory/ocp46.inv`(for example: /dev/sdb), the HD is for Private image registry of ocp or as the storage of `storageclasses` which will dopted by applications(for example: CP4D), so suggest bigger size, for example: about 1T for cp4d.

- Updated `inventory/ocp46.inv` to set:  
  1. IPs of `bastion`, `bootstrap`, `master` and `worker`. remember we try to define the IP of each roles and ignore the original IP assigned by dhcp(if existed).
  2. The number of `master` and `Worker`
- If we expect to setup a single master cluster, you must:
  1. Update number of `master` and `Worker` in `inventory/ocp46.inv`
  ```
    vm_number_of_masters=3
    vm_number_of_workers=3
  ```
  2. Update config fo DNS server: `roles/install/tasks/dns_server.j2` then set below items as your expect:
  ```
    address=/etcd-0.{{cluster_name}}.{{domain_name}}/{{groups['masters'][0]}}
    address=/etcd-1.{{cluster_name}}.{{domain_name}}/{{groups['masters'][1]}}
    address=/etcd-2.{{cluster_name}}.{{domain_name}}/{{groups['masters'][2]}}
    srv-host=_etcd-server-ssl._tcp.{{cluster_name}}.{{domain_name}},etcd-0.{{cluster_name}}.{{domain_name}},2380,0,10
    srv-host=_etcd-server-ssl._tcp.{{cluster_name}}.{{domain_name}},etcd-1.{{cluster_name}}.{{domain_name}},2380,0,10
    srv-host=_etcd-server-ssl._tcp.{{cluster_name}}.{{domain_name}},etcd-2.{{cluster_name}}.{{domain_name}},2380,0,10
  ```
  3. Update installation config of OCP: `roles/install/tasks/ocp_install_config.j2`, set the number of master as you expect:
  ```
  controlPlane:
  hyperthreading: Enabled
  name: master
    {% if rhcos_installation_method|upper!="IPI" %}
    replicas: 3
    {% else %}
  ```
then get into scripts folder, run install

```
cd /ocp4-workspace/installation-scripts
./prepare.sh install
```

**Check**
- curl -u admin:passw0rd https://registry.ocp48.cluster.local.com:5000/v2/_catalog
expect output:
`{"repositories":["ocp4/openshift4","sig-storage/nfs-subdir-external-provisioner"]}`

- systemctl status dnsmasq
Something it will hit error:
```
[root@localhost installation-scripts]# systemctl status dnsmasq
● dnsmasq.service - DNS caching server.
   Loaded: loaded (/usr/lib/systemd/system/dnsmasq.service; enabled; vendor preset: disabled)
   Active: failed (Result: exit-code) since Sun 2022-04-24 23:12:13 EDT; 1min 49s ago
 Main PID: 35376 (code=exited, status=2)

Apr 24 23:12:13 bastion.ocp48.cluster.local.com systemd[1]: Started DNS caching server..
Apr 24 23:12:13 bastion.ocp48.cluster.local.com dnsmasq[35376]: dnsmasq: failed to create listening socket for port 53: Address already in use
Apr 24 23:12:13 bastion.ocp48.cluster.local.com systemd[1]: dnsmasq.service: Main process exited, code=exited, status=2/INVALIDARGUMENT
Apr 24 23:12:13 bastion.ocp48.cluster.local.com dnsmasq[35376]: failed to create listening socket for port 53: Address already in use
Apr 24 23:12:13 bastion.ocp48.cluster.local.com dnsmasq[35376]: FAILED to start up
Apr 24 23:12:13 bastion.ocp48.cluster.local.com systemd[1]: dnsmasq.service: Failed with result 'exit-code'.
```

no worry, kill the process who used the address and restart the `dnsmasq`


everything needed to do for bastion is ready, then you can install

### Start boostrap, master, worker

bootstrap/master/worker should install rhcos

start bootstrap, you will get into a temp system. modify ip related and get ignition from bastion.

```
sudo nmcli connection show | grep -v UUID | awk '{print $4}' | while read x; do sudo nmcli connection modify $x ipv4.addresses "<bootstrap ip>/25" ipv4.gateway <gateway> ipv4.dns <bastion ip> ipv4.method manual connection.autoconnect yes connection.interface-name <interface name> con-name <interface name>; done

sudo nmcli connection reload
sudo nmcli connection up <interface name>

sudo coreos-installer install --copy-network --ignition-url http://<bastion ip>:9080/ocp4-workspace/dependencies/bootstrap.ign --insecure-ignition /dev/sda 

sudo reboot
```

for example
```
sudo nmcli connection show | grep -v UUID | awk '{print $4}' | while read x; do sudo nmcli connection modify $x ipv4.addresses "192.168.100.41/25" ipv4.gateway 192.168.100.1 ipv4.dns 192.168.100.40 ipv4.method manual connection.autoconnect yes connection.interface-name ens192 con-name ens192; done

sudo nmcli connection reload
sudo nmcli connection up ens192

sudo coreos-installer install --copy-network --ignition-url http://192.168.100.40:9080/ocp4-workspace/dependencies/bootstrap.ign --insecure-ignition /dev/sda 

sudo reboot
```

start master and worker same way

### On bastion node

Get into scripts folder `/ocp4-workspace/ocp_install/scripts/`, execute the following in order

```
./wait_bootstrap.sh
./remove_bootstrap.sh
./wait_nodes_ready.sh
./create_admin_user.sh
./wait_install.sh
./wait_co_ready.sh
```

Then the OCP is ready and you can login
to create nfs `storageclasses`, you need:
`./create_nfs_sc.sh`

and craete ocp's private image repositry, you need:
`create_registry_storage.sh`


