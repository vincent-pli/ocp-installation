#!/bin/bash

WORKING_DIR="/ocp4_downloads"

CENTOS_IMAGE_URL="http://linux.mirrors.es.net/centos/8.4.2105/isos/x86_64/CentOS-8.4.2105-x86_64-dvd1.iso"
CENTOS_IMAGE_PATH="${WORKING_DIR}/dependencies/"
CENTOS_IMAGE_NAME="centos8.iso"

install_tools() {
    echo "download centos for local yum sources..."
    mkdir -p ${CENTOS_IMAGE_PATH}
    if [ ! -f ${CENTOS_IMAGE_PATH}/${CENTOS_IMAGE_NAME} ]; then
        wget ${CENTOS_IMAGE_URL} -O ${CENTOS_IMAGE_PATH}/${CENTOS_IMAGE_NAME}
    fi
    echo "mount iso..."
    mkdir -p /iso
    mount ${CENTOS_IMAGE_PATH}/${CENTOS_IMAGE_NAME} /iso
    echo "[InstallMedia]
name=CentOS Linux 8
baseurl=file:///iso/BaseOS
    gpgcheck=0
    enabled=1
    
    [AppStream]
    name=AppStream
    baseurl=file:///iso/AppStream
    enabled=1
    gpgcheck=0" > /etc/yum.repos.d/centos8.repo
    echo "install tools..."
    #yum install -y vim
}

install_tools
