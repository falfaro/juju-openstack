#!/bin/bash

VIRT_TYPE=$(juju config nova-compute virt-type)
case $VIRT_TYPE in
  lxd)
    echo "info: nova-lxd detected"
    XENIAL_IMG=xenial-server-cloudimg-amd64-root.tar.gz
    CIRROS_IMG=cirros-0.4.0~pre1-x86_64-lxc.tar.gz
    ;;
  kvm)
    echo "info: nova-kvm detected"
    XENIAL_ING=xenial-server-cloudimg-amd64-disk1.img
    CIRROS_IMG=cirros-0.4.0~pre1-x86_64-disk.img
    ;;
  *)
    echo "error: unsupported nova driver $VIRT_TYPE"
    exit 1
esac

source novarc
openstack token issue || exit 1

# Glance
mkdir -p ~/images

if [ ! -f ~/images/$XENIAL_IMG ]; then
  wget -O ~/images/$XENIAL_IMG http://cloud-images.ubuntu.com/xenial/current/$XENIAL_IMG
fi
glance image-create --name="xenial" --visibility public --progress \
                    --container-format=bare --disk-format=root-tar \
                    --property architecture="x86_64" < ~/images/$XENIAL_IMG

if [ ! -f ~/images/$CIRROS_IMG ]; then
  wget -O ~/images/$CIRROS_IMG http://download.cirros-cloud.net/0.4.0~pre1/$CIRROS_IMG
fi
glance image-create --name="cirros" --visibility public --progress \
                    --container-format=bare --disk-format=root-tar \
                    --property architecture="x86_64" < ~/images/$CIRROS_IMG

# Neutron
./neutron-ext-net --network-type flat -g 10.99.0.1 -c 10.99.0.0/20 -f 10.99.0.10:10.99.0.254 ext_net
neutron subnet-update --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 ext_net_subnet
./neutron-tenant-net -t admin -r provider-router internal 10.5.5.0/24

# Allow SSH and ICMP
SECURITY_GROUP_ID=$(openstack security group list --project $OS_TENANT_NAME -c ID -f json | jq -r '.[0].ID')
openstack security group rule create --ingress --ethertype IPv4 --dst-port 22 --protocol tcp $SECURITY_GROUP_ID
openstack security group rule create --ingress --ethertype IPv4 --protocol icmp $SECURITY_GROUP_ID

# Nova
nova keypair-add --pub-key ~/.ssh/id_rsa.pub mykey
nova flavor-create m1.small auto 1024 4 1
nova boot --image xenial --flavor m1.small --key-name mykey --nic net-name=internal --user-data=xenial-cloud-init.cfg xenial-test
nova boot --image cirros --flavor m1.small --key-name mykey --nic net-name=internal cirros-test
