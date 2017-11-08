# Basic OpenStack Cloud

This example bundle deploys a basic OpenStack Cloud on Ubuntu 16.04 LTS, providing Dashboard, Compute, Network, Block Storage, Object Storage, Identity and Image services. It is based on the work of many others, including https://insights.ubuntu.com/2016/01/31/nodes-networking-deploying-openstack-on-maas-1-9-with-juju/.

## Requirements

This example bundle is designed to run on KVM using Juju 2.x with [MAAS][] (Metal-as-a-Service); you will need to have setup a [MAAS][] deployment with 5 virtual (KVM) servers prior to using this bundle. All servers will be connected to an isolated "virsh" network named "maas", to which the MAAS controller is also attached:

    <network connections='10'>
      <name>maas</name>
      <bridge name='virbr2' stp='on' delay='0'/>
      <mac address='52:54:00:34:73:57'/>
      <domain name='maas'/>
    </network>

Of these 5 servers:

1 server, named "node-11", for Neutron Gateway and Ceph with RabbitMQ and MySQL under LXC containers, and using the following configuration:

 - ens3 and ens4 physical network interfaces attached to the shared L2 network with Internet access
 - ens3.50, ens3.100, ens3.150 VLAN subinterfaces
 - ens4.99, ens4.200, ens4.250 VLAN subinterfaces
 - 8GB of RAM
 - 2 CPU cores
 - /dev/vda, 20GB VirtIO drive, used by MAAS for the OS install
 - /dev/vdb, 80GB VirtIO drive, used for Ceph storage

3 servers, named "node-12", "node-21" and "node-22", for Nova Compute and Ceph, with Keystone, Glance, Neutron, Nova Cloud Controller, Ceph RADOS Gateway, Cinder and Horizon under LXC containers, and using the following configuration:

 - ens3 and ens4 physical network interfaces attached to the shared L2 network with Internet access
 - ens3.50, ens3.100, ens3.150 VLAN subinterfaces
 - ens4.30, ens4.200, ens4.250 VLAN subinterfaces
 - 8GB of RAM
 - 2 CPU cores
 - /dev/vda, 20GB VirtIO drive, used by MAAS for the OS install
 - /dev/vdb, 80GB VirtIO drive, used for Ceph storage

1 server, named "node-31", for the Juju controller, and using the following configuration:

 - ens3 physical network interface attached to the shared L2 network with Internet access

## Initial

### Juju

The recommended approach is installing Juju using snap:

    $ sudo snap install --classic conjure-up

Then, prepare the configuration files required to grant Juju access to the MAAS cluster:

    $ maas list
    20-admin http://10.1.0.10:5240/MAAS/api/2.0/ wfLvEXAUYjj8dHjqGJ:Pqc4AZPffCre7tP795:eZabd2A5vs6k2DbzHPnFwKtpnhZEgv62

And:

    $ cat > maas-hw-cloud.yaml
    clouds:
      maas-hw:
        type: maas
        auth-types: [oauth1]
        endpoint: http://10.1.0.10:5240/MAAS
    $ cat > maas-hw-creds.yaml
    credentials:
      maas-hw:
        default-credential: 20-admin
        hw-juju:
          auth-type: oauth1
          maas-oauth: wfLvEXAUYjj8dHjqGJ:Pqc4AZPffCre7tP795:eZabd2A5vs6k2DbzHPnFwKtpnhZEgv62

And finally:

    $ juju add-cloud maas-hw ~/maas-hw-clouds.yaml
    $ juju add-credential maas-hw -f ~/maas-hw-creds.yaml

Getting network connectivity right is extremely important and can also be tricky. A wrong network configuration will likely yield a broken OpenStack cluster. To save some time, there is the "deploy-4-nodes-pinger.sh" script that deploys a custom Juju bundle with the "pinger" charm to check connectivity between all components. The script launches the bundle and watches for Juju to finish deployment. If everything is properly configured, all units from the bundle will be shown and green. Exiting the script (with Ctrl-C) will destroy the deployment and then one can proceed onto deploying OpenStack.

## Components

All virtual servers (not LXC containers) will also have NTP installed and configured to keep time in sync.

Neutron Gateway, Nova Compute and Ceph services are designed to be horizontally scalable.

To horizontally scale Nova Compute:

    juju add-unit nova-compute # Add one more unit
    juju add-unit -n5 nova-compute # Add 5 more units

To horizontally scale Neutron Gateway:

    juju add-unit neutron-gateway # Add one more unit
    juju add-unit -n2 neutron-gateway # Add 2 more unitsa

To horizontally scale Ceph:

    juju add-unit ceph-osd # Add one more unit
    juju add-unit -n50 ceph-osd # add 50 more units

**Note:** Ceph can be scaled alongside Nova Compute or Neutron Gateway by adding units using the --to option:

    juju add-unit --to <machine-id-of-compute-service> ceph-osd

**Note:** Other services in this bundle can be scaled in-conjunction with the hacluster charm to produce scalable, highly avaliable services - that will be covered in a different bundle.

## Ensuring it's working

To ensure your cloud is functioning correctly, download this bundle and then run through the following sections.

All commands are executed from within the expanded bundle.

### Install OpenStack client tools

In order to configure and use your cloud, you'll need to install the appropriate client tools:

    sudo add-apt-repository cloud-archive:newton -y
    sudo apt update
    sudo apt install python-novaclient python-keystoneclient python-glanceclient \
        python-neutronclient python-openstackclient -y

### Accessing the cloud

Check that you can access your cloud from the command line:

    source novarc
    openstack catalog list

You should get a full listing of all services registered in the cloud which should include identity, compute, image and network.

### Configuring an image

In order to run instances on your cloud, you'll need to upload an image to boot instances from:

    curl http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img | \
        openstack image create --public --container-format=bare --disk-format=qcow2 xenial

### Configure networking

For the purposes of a quick test, we'll setup an 'external' network and shared router ('provider-router') which will be used by all tenants for public access to instances:

    ./neutron-ext-net --network-type flat \
        -g <gateway-ip> -c <network-cidr> \
        -f <pool-start>:<pool-end> ext_net

for example (for a private cloud):

    ./neutron-ext-net --network-type flat \
        -g 10.99.0.1 -c 10.99.0.0/20 \
        -f 10.99.0.10:10.99.0.254 ext_net
    neutron subnet-update \
        --dns-nameserver 8.8.8.8 \
        --dns-nameserver 8.8.4.4 ext_net_subnet

You'll need to adapt the parameters for the network configuration that eno2 on all the servers is connected to; in a public cloud deployment these ports would be connected to a publicly addressable part of the Internet.

We'll also need an 'internal' network for the admin user which instances are actually connected to:

    ./neutron-tenant-net -t admin \
        -r provider-router internal 10.5.5.0/24

Neutron provides a wide range of configuration options; see the [OpenStack Neutron][] documentation for more details.

### Configuring a flavor

Starting with the OpenStack Newton release, default flavors are no longer created at install time. You therefore need to create at least one machine type before you can boot an instance:

    nova flavor-create m1.small auto 1024 4 1

### Booting an instance

First generate a SSH keypair so that you can access your instances once you've booted them:

    nova keypair-add mykey > ~/.ssh/id_rsa_cloud

**Note:** you can also upload an existing public key to the cloud rather than generating a new one:

    nova keypair-add --pub-key ~/.ssh/id_rsa.pub mykey

You can now boot an instance on your cloud:

    nova boot --image xenial --flavor m1.small --key-name mykey \
        --nic net-name=internal --user-data=xenial-cloud-init.cfg \
        xenial-test

### Attaching a volume

First, create a volume in cinder:

    cinder create 10 # Create a 10G volume

then attach it to the instance we just booted in nova:

    nova volume-attach xenial-test <uuid-of-volume> /dev/vdc

The attached volume will be accessible once you login to the instance (see below).  It will need to be formatted and mounted!

### Accessing your instance

In order to access the instance you just booted on the cloud, you'll need to assign a floating IP address to the instance:

    nova floating-ip-create
    nova add-floating-ip <uuid-of-instance> <new-floating-ip>

and then allow access via SSH (and ping) - you only need todo this once:

    neutron security-group-rule-create --protocol icmp \
        --direction ingress default
    neutron security-group-rule-create --protocol tcp \
        --port-range-min 22 --port-range-max 22 \
        --direction ingress default

After running these commands you should be able to access the instance:

    ssh ubuntu@<new-floating-ip>

## Remote access

One can use `sshuttle` to tunnel traffic to this environment (MAAS and OpenStack):

     sshuttle -r hostname 10.1.0.0/20 10.14.0.0/20 10.50.0.0/20

To retrieve the URL where OpenStack Horizon is rechable:

    ./get-horizon-url.sh

The URL for accessing MAAS:

    MAAS: http://10.1.0.10:5240/MAAS/

## Troubleshooting

### Dry run

To get a summary of the deployment steps (without actually deploying) a dry run can be performed:

    juju deploy --dry-run bundle-4-nodes.newton.yaml

### Juju retry-provisioning

You can use the `retry-provisioning` command in cases where deploying applications, adding units, or adding machines fails. It allows you to specify machines which should be retried to resolve errors reported with `juju status`.

For example, after having deployed 100 units and machines, status reports that machines '3', '27' and '57' could not be provisioned because of a 'rate limit exceeded' error. You can ask Juju to retry:

    juju retry-provisioning 3 27 57

### Juju resolved

To force a unit in error state to be retried one can use `juju resolved`:

    juju resolved keystone/1

## What next?

Configuring and managing services on an OpenStack cloud is complex; take a look a the [OpenStack Admin Guide][] for a complete reference on how to configure an OpenStack cloud for your requirements.

## Useful Cloud URLs

 - OpenStack Dashboard: http://openstack-dashboard_ip/horizon

[MAAS]: http://maas.ubuntu.com/docs
[Simplestreams]: https://launchpad.net/simplestreams
[OpenStack Neutron]: http://docs.openstack.org/admin-guide-cloud/content/ch_networking.html
[OpenStack Admin Guide]: http://docs.openstack.org/user-guide-admin/content
