#!/bin/bash
exec 2>/dev/null
ceph osd pool create kube 1024
if [ ! -f ceph.client.kube.keyring ]; then
  ceph auth get-or-create client.kube mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=kube' -o ceph.client.kube.keyring
fi
kubectl delete secret ceph-secret-admin --namespace=kube-system
kubectl create secret generic ceph-secret-admin --from-literal=key="$(ceph auth get-key client.admin)" --namespace=kube-system --type=kubernetes.io/rbd
kubectl delete secret ceph-secret-user
kubectl create secret generic ceph-secret-user --from-literal=key="$(ceph auth get-key client.kube)" --type=kubernetes.io/rbd
kubectl delete storageclass slow
cat << EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: slow
provisioner: kubernetes.io/rbd
parameters:
    monitors: '$(cat /etc/ceph/ceph.conf | grep 'mon.host = ' | sed 's,mon.host = ,,g' | tr ' ' ',')'
    adminId: admin
    adminSecretName: ceph-secret-admin
    adminSecretNamespace: kube-system
    pool: kube
    userId: kube
    userSecretName: ceph-secret-user
    imageFormat: "1"
EOF
