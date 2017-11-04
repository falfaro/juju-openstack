#!/bin/bash
echo http://$(juju run --unit openstack-dashboard/0 'unit-get private-address')/horizon/
