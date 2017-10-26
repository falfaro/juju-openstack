#!/bin/bash

set -e
: ${JUJU_BIN:=/snap/bin/juju}

$JUJU_BIN version
$JUJU_BIN destroy-controller openstack-base-hw-x -y || true
$JUJU_BIN bootstrap maas-hw openstack-base-hw-x --config=./maas-hw-config.yaml --to node-31
$JUJU_BIN switch openstack-base-hw-x:controller

sleep 15

$JUJU_BIN deploy -m openstack-base-hw-x:controller bundle-4-nodes.yaml
watch -c "$JUJU_BIN status --color -m openstack-base-hw-x:controller"
