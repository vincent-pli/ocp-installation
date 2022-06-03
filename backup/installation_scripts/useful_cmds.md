
```
yum install -y --downloadonly --downloaddir=<path>

yum install -y ansible bind-utils buildah chrony dnsmasq git \
    haproxy httpd-tools jq libvirt net-tools nfs-utils nginx podman \
    python3 python3-netaddr python3-passlib python3-pip python3-policycoreutils python3-pyvmomi python3-requests \
    screen sos syslinux-tftpboot wget yum-utils \
    --downloadonly --downloaddir=./rpm_repos
```

```
systemctl start/stop/status named
```

```
systemctl restart NetworkManager
```

```
rpm -Uvh --force --nodeps *.rpm
```