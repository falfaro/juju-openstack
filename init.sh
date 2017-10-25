#!/bin/bash
source novarc
openstack token issue || exit 1

# Glance
curl http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img | openstack image create --public --container-format=bare --disk-format=qcow2 xenial
curl http://download.cirros-cloud.net/0.4.0~pre1/cirros-0.4.0~pre1-x86_64-disk.img | openstack image create --public --container-format=bare --disk-format=qcow2 cirros

# Neutron
./neutron-ext-net --network-type flat -g 10.99.0.1 -c 10.99.0.0/20 -f 10.99.0.10:10.99.0.254 ext_net
neutron subnet-update --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 ext_net_subnet
./neutron-tenant-net -t admin -r provider-router internal 10.5.5.0/24

# Nova
nova keypair-add --pub-key ~/.ssh/id_rsa.pub mykey
nova flavor-create m1.small auto 1024 4 1
nova boot --image xenial --flavor m1.small --key-name mykey --nic net-name=internal --user-data=xenial-cloud-init.cfg xenial-test
nova boot --image cirros --flavor m1.small --key-name mykey --nic net-name=internal cirros-test
