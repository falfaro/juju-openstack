#!/bin/bash
 
set -e
: ${JUJU_BIN:=/snap/bin/juju}
 
$JUJU_BIN version
$JUJU_BIN kill-controller pinger-maas-hw -y || true
$JUJU_BIN bootstrap maas-hw pinger-maas-hw --config=./maas-hw-config.yaml --to node-31
$JUJU_BIN switch pinger-maas-hw:controller
 
sleep 5
 
$JUJU_BIN deploy -m pinger-maas-hw:controller pinger-bundle-3-nodes.yaml
#$JUJU_BIN add-unit -m pinger-maas-hw:controller pinger-compute-storage-node --to 0
#$JUJU_BIN add-unit -m pinger-maas-hw:controller pinger-compute-storage-node --to lxd:0
 
watch -c "$JUJU_BIN status --color -m pinger-maas-hw:controller"
 
$JUJU_BIN kill-controller pinger-maas-hw
