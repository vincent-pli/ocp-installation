#!/bin/bash

STAGE=$1

if [ $# == 0  ]; then
    echo "./run.sh [prepare/install], must provide one of the two values"
elif [ $STAGE == "prepare" ]; then
    SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
    echo $SHELL_FOLDER
    rpm -ivh $SHELL_FOLDER/rpms/*.rpm --force --nodeps
    ansible-playbook -i ./inventory/ocp48.inv ./vmware_baremetal-offline-prepare.yaml
elif [ $STAGE == "install" ]; then
    SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
    echo $SHELL_FOLDER
    rpm -ivh $SHELL_FOLDER/rpms/*.rpm --force --nodeps
    SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
    pushd $SCRIPT_DIR > /dev/null
    INVENTORY_FILE_PARAM="./inventory/ocp48.inv"
    inventory_file=$(realpath $INVENTORY_FILE_PARAM)
    ansible-playbook -i $inventory_file ./vmware_baremetal-offline-install.yaml \
      -e inventory_file=$inventory_file \
      -e script_dir=$SCRIPT_DIR
fi