#!/bin/bash

set -e
: ${JUJU_BIN:=/snap/bin/juju}

$JUJU_BIN version
#$JUJU_BIN destroy-controller --destroy-all-models openstack-base-hw-x -y && sleep 30s || true
$JUJU_BIN bootstrap maas-hw openstack-base-hw-x --no-gui --config=./maas-hw-config.yaml --to node-32
$JUJU_BIN destroy-model openstack || :
$JUJU_BIN add-model openstack
$JUJU_BIN deploy bundle-4-nodes.pike.yaml
watch -c "$JUJU_BIN status --color"
#git clone https://github.com/wwwtyro/juju-status.git || true
#watch -c ./juju-status/juju-status unit.workload unit.juju unit.message
