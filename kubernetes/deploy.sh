#!/bin/bash
set -x

function fail {
  echo $@ >&2
  exit 1
}

function retry {
  local n=1
  local max=10
  local delay=1m
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max."
        sleep $delay;
      else
        fail "The command '$@' has failed after $n attempts."
      fi
    }
  done
}

juju destroy-model -y kubernetes
juju add-model kubernetes
juju deploy bundle.calico.yaml

juju wait -w

sudo snap install --classic kubectl 2>/dev/null
sudo snap install helm 2>/dev/null

mkdir -p ~/.kube
retry juju scp kubernetes-master/0:config ~/.kube/config
mkdir -p ~/snap/helm/common/kube
cp ~/.kube/config ~/snap/helm/common/kube/config

cat rbd-storage-class.sh | juju ssh --pty=false kubernetes-master/0 -- bash -l

kubectl create -f coredns.yaml

DNS=$(kubectl --namespace=kube-system get -o json service coredns | jq .spec.clusterIP)
juju config kubernetes-worker kubelet-extra-args='cluster-dns='${DNS}' cluster-domain=cluster.local'

kubectl create -f helm-rbac-config.yaml
helm init --service-account tiller
