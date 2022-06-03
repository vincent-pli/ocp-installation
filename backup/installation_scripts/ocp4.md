# Air gap OCP4.6 installation

## 1. prepare bastion
---

logon using `root`

config repostory, centos 8
```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
```

install packages
```
yum install -y wget podman httpd-tools jq ansible bind-utils \
    buildah chrony dnsmasq git \
    haproxy httpd-tools jq libvirt net-tools nfs-utils nginx \
    python3 python3-netaddr python3-passlib python3-pip python3-policycoreutils python3-pyvmomi python3-requests \
    screen sos syslinux-tftpboot wget yum-utils vim
```
(for downloaded rpms)
```
rpm -ivh *rpm
```

clone repo
```
cd /root
git clone https://github.com/IBM-ICP4D/cloud-pak-ocp-4.git
```

update `/etc/hosts`
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.99.92.62(bastion ip) download.ocp46.mcmp.cluster.com registry.ocp46.cluster.ibm.com
```

set environment variables
```
cd /root
touch ocp_env
vim ocp_env
```
paste the following to that
```
export REGISTRY_SERVER=registry.ocp46.cluster.ibm.com
export REGISTRY_PORT=5000
export LOCAL_REGISTRY="${REGISTRY_SERVER}:${REGISTRY_PORT}"
export EMAIL="hanzhis@cn.ibm.com"
export REGISTRY_USER="admin"
export REGISTRY_PASSWORD="passw0rd"

export OCP_RELEASE="4.6.23"
export RHCOS_RELEASE="4.6.8"
export LOCAL_REPOSITORY='ocp4/openshift4' 
export PRODUCT_REPO='openshift-release-dev' 
export LOCAL_SECRET_JSON='/ocp4_downloads/ocp4_install/ocp_pullsecret.json' 
export RELEASE_NAME="ocp-release"
```

```
mkdir -p /ocp4_downloads/{clients,dependencies,ocp4_install,install,tools}
mkdir -p /ocp4_downloads/registry/{auth,certs,data,images}
```

retrive openshift client and coreos
```
cd /ocp4_downloads/clients
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.6/openshift-client-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.6/openshift-install-linux.tar.gz
```

rhcos for pxe
```
cd /ocp4_downloads/dependencies
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.6/latest/rhcos-${RHCOS_RELEASE}-x86_64-metal.x86_64.raw.gz
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.6/latest/rhcos-${RHCOS_RELEASE}-x86_64-installer.x86_64.iso
```

rhcos for vmware
```
cd /ocp4_downloads/dependencies
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.6/latest/rhcos-${RHCOS_RELEASE}-x86_64-vmware.x86_64.ova
```

install openshift client
```
tar xvzf /ocp4_downloads/clients/openshift-client-linux.tar.gz -C /usr/local/bin
```

generate certificate
```
cd /ocp4_downloads/registry/certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt -subj "/C=US/ST=/L=/O=/CN=$REGISTRY_SERVER" -addext "subjectAltName = DNS:registry.ocp46.cluster.ibm.com"
```

create password for registry
```
htpasswd -bBc /ocp4_downloads/registry/auth/htpasswd $REGISTRY_USER $REGISTRY_PASSWORD
```

download registry image
```
podman pull docker.io/library/registry:2
podman save -o /ocp4_downloads/registry/images/registry-2.tar docker.io/library/registry:2
```

download NFS provisioner image
```
podman pull quay.io/external_storage/nfs-client-provisioner:latest
podman save -o /ocp4_downloads/registry/images/nfs-client-provisioner.tar quay.io/external_storage/nfs-client-provisioner:latest
```

create registry pod
```
podman run --name mirror-registry --publish $REGISTRY_PORT:5000 \
     --detach \
     --volume /ocp4_downloads/registry/data:/var/lib/registry:z \
     --volume /ocp4_downloads/registry/auth:/auth:z \
     --volume /ocp4_downloads/registry/certs:/certs:z \
     --env "REGISTRY_AUTH=htpasswd" \
     --env "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
     --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
     --env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
     --env REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
     docker.io/library/registry:2
```

add certificate to trusted store
```
/usr/bin/cp -f /ocp4_downloads/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

check
```
curl -u $REGISTRY_USER:$REGISTRY_PASSWORD https://${LOCAL_REGISTRY}/v2/_catalog
```

create pull secret file
```
AUTH=$(echo -n "$REGISTRY_USER:$REGISTRY_PASSWORD" | base64 -w0)

CUST_REG='{"%s": {"auth":"%s", "email":"%s"}}\n'
printf "$CUST_REG" "$LOCAL_REGISTRY" "$AUTH" "$EMAIL" > /tmp/local_reg.json

jq --argjson authinfo "$(</tmp/local_reg.json)" '.auths += $authinfo' /tmp/ocp_pullsecret.json > /ocp4_downloads/ocp4_install/ocp_pullsecret.json
```

cat `/ocp4_downloads/ocp4_install/ocp_pullsecret.json`, should like:
```
{
  "auths": {
    "cloud.openshift.com": {
      "auth": ...,
      "email": "hanzhis@cn.ibm.com"
    },
    "quay.io": {
      "auth": ...,
      "email": "hanzhis@cn.ibm.com"
    },
    "registry.connect.redhat.com": {
      "auth": ...,
      "email": "hanzhis@cn.ibm.com"
    },
    "registry.redhat.io": {
      "auth": ...,
      "email": "hanzhis@cn.ibm.com"
    },
    "registry.ocp43.coc.ibm.com:5000": {
      "auth": "YWRtaW46cGFzc3cwcmQ=",
      "email": "hanzhis@cn.ibm.com"
    }
  }
}
```

mirror registry
```
oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-x86_64 \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}
```

output:
```
imageContentSources:
- mirrors:
  - registry.ocp46.cluster.ibm.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.ocp46.cluster.ibm.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

start nginx, vim `/etc/nginx/nginx.conf`
```
    server {
        listen       8080 default_server;
```
```
    location /ocp4_downloads {
            autoindex on;
        }
```
```
cp -r /ocp4_downloads /usr/share/nginx/html
```
```
systemctl restart nginx;systemctl enable nginx
```
check
```
curl -L -s http://${REGISTRY_SERVER}:8080/ocp4_downloads --list-only
```

generate openshift install binary
```
cd /ocp4_downloads/install
oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}"
echo $?
```
should echo `0`

install config 
```
cd /ocp4_downloads/install
touch install-config.yaml
vim install-config.yaml
```
paste
```
apiVersion: v1
baseDomain: mcmp.cluster.com
controlPlane:
  name: master
  hyperthreading: Enabled 
  replicas: 3
compute:
- name: worker
  hyperthreading: Enabled
  replicas: 3
metadata:
  name: ocp46
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 172.18.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {} 
fips: false
pullSecret: '{"auths": "registry.ocp43.coc.ibm.com:5000": {"auth":"YWRtaW46cGFzc3cwcmQ=","email": "hanzhis@cn.ibm.com"}}'
sshKey: 'ssh-ed25519 AAAA...'
additionalTrustBundle: |
     -----BEGIN CERTIFICATE-----
     <...base-64-encoded, DER - CA certificate>
     -----END CERTIFICATE-----
imageContentSources:
- mirrors:
  - registry.ocp46.cluster.ibm.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.ocp46.cluster.ibm.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```
> pullSecret – only the information about your registry is needed.

> sshKey – the contents of your id_rsa.pub file (or another ssh public key that you want to use)

> additionalTrustBundle – this is your crt file for your registry. (i.e. the output of cat domain.crt)

> imageContentSources – What is the local registry is and the expected original source that should be in the metadata (otherwise they should be considered as tampered)

create manifest
```
cd /ocp4_downloads/install
openshift-install create manifests --dir=./
```
```
vim manifests/cluster-scheduler-02-config.yml 
mastersSchedulable false
```
create ignition
```
openshift-install create ignition-configs --dir=./
```

## 2. install
---

login bastion, check boostrap
```
cd /ocp4_downloads/install
openshift-install wait-for bootstrap-
complete --log-level debug
```

check progress
```
openshift-install wait-for install-complete --log-level debug
```

approve manualy
```
oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | 
.metadata.name' | xargs oc adm certificate approve
```