#!/bin/bash

set -e
: ${JUJU_BIN:=/snap/bin/juju}

$JUJU_BIN version
$JUJU_BIN kill-controller openstack-base-hw-x -y || true
$JUJU_BIN bootstrap maas-hw openstack-base-hw-x --config=./maas-hw-config.yaml --to node-31
$JUJU_BIN switch openstack-base-hw-x:controller

sleep 5

$JUJU_BIN deploy -m openstack-base-hw-x:controller bundle-4-nodes.yaml
#$JUJU_BIN remove-unit -m openstack-base-hw-x:controller openstack-dashboard/0
#$JUJU_BIN add-unit -m openstack-base-hw-x:controller openstack-dashboard --to lxd:0
#$JUJU_BIN remove-unit -m openstack-base-hw-x:controller keystone/0
#$JUJU_BIN add-unit -m openstack-base-hw-x:controller keystone --to lxd:0
#$JUJU_BIN add-unit -m openstack-base-hw-x:controller ceph-osd --to 0
#$JUJU_BIN add-unit -m openstack-base-hw-x:controller ceph-mon --to lxd:0
#$JUJU_BIN add-unit -m openstack-base-hw-x:controller nova-compute --to 0

watch -c "$JUJU_BIN status --color -m openstack-base-hw-x:controller"

#$JUJU_BIN kill-controller openstack-base-hw-x
