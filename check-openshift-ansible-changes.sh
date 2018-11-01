#!/bin/bash
# Check for changes of openshift-console in openshift-ansible
# Potential changes can be ported to kubevirt-ansible

set -ex

export UNIQUE=`mktemp -u ~/tmp/openshift-ansible-XXXXX`
git clone https://github.com/openshift/openshift-ansible.git ${UNIQUE}
cd ${UNIQUE}
git log -n 1 roles/openshift_console
git log -n 1 playbooks/openshift-console
