#!/bin/bash

set -e
: ${JUJU_BIN:=/snap/bin/juju}

$JUJU_BIN version
$JUJU_BIN destroy-controller --destroy-all-models openstack-base-hw-x -y && sleep 30s || true
$JUJU_BIN bootstrap maas-hw openstack-base-hw-x --no-gui --config=./maas-hw-config.yaml --to node-32
$JUJU_BIN switch openstack-base-hw-x:controller

sleep 15

$JUJU_BIN deploy -m openstack-base-hw-x:controller ./bundle-4-nodes.newton.yaml
watch -c "$JUJU_BIN status --color -m openstack-base-hw-x:controller"
#git clone https://github.com/wwwtyro/juju-status.git || true
#watch -c ./juju-status/juju-status unit.workload unit.juju unit.message
