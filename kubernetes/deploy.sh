#!/bin/sh
set -x

juju destroy-model -y kubernetes
juju add-model kubernetes
juju deploy bundle.flannel.yaml

juju wait -w

sudo snap install --classic kubectl 2>/dev/null
mkdir -p ~/.kube
juju scp kubernetes-master/0:config ~/.kube/config

cat rbd-storage-class.sh | juju ssh --pty=false kubernetes-master/0 -- bash -l

kubectl create -f coredns.yaml

DNS=$(kubectl --namespace=kube-system get -o json service coredns | jq .spec.clusterIP)
juju config kubernetes-worker kubelet-extra-args='cluster-dns='${DNS}' cluster-domain=cluster.local'
