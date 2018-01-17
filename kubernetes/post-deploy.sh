#!/bin/bash

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

sudo snap install --classic kubectl
sudo snap install helm
mkdir -p ~/.kube

retry juju scp kubernetes-master/0:config ~/.kube/config

mkdir -p ~/snap/helm/common/kube/config
cp ~/.kube/config ~/snap/helm/common/kube/config
