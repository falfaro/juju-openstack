#!/bin/bash
sudo snap install --classic kubectl
mkdir -p ~/.kube
juju scp kubernetes-master/0:config ~/.kube/config
