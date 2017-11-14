# Kubernetes with Ceph

Code and other bits were borrowed from https://github.com/kubernetes/examples/tree/master/staging/persistent-volume-provisioning.
There are two bundles provided: the default `bundle.yaml` uses Flannel as the network provider while `bundle.calico.yaml` uses Calico.
To deploy:

```
$JUJU_BIN bootstrap maas-hw openstack-base-hw-x --config=../maas-hw-config.yaml --to node-32
$JUJU_BIN deploy ./bundle.yaml
```

After the deployment has finished, some post-installation steps are required in order to configure Ceph and integrate it with Kubernetes:

```
$ juju scp * kubernetes-master/0:
$ juju ssh kubernetes-master:0
ubuntu@node-21:~$ ./post-deploy.sh
ubuntu@node-21:~$ ./rbd-storage-class.sh
```

In order to test the integration:

```
ubuntu@node-21:~$ kubectl create -f claim1.yaml
ubuntu@node-21:~$ kubectl get pvc
NAME      STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
claim1    Bound     pvc-1ef00fd9-c95a-11e7-b620-525400a360c5   3Gi        RWO            slow           6m
ubuntu@node-21:~$ kubectl create -f pod.yaml
```

After some time, which is required for the Pod and container to be started up:

```
ubuntu@node-21:~$ kubectl get pods
NAME                             READY     STATUS    RESTARTS   AGE
default-http-backend-mzm6n       1/1       Running   0          20m
nginx-ingress-controller-cfggv   1/1       Running   0          20m
server-78k7k                     1/1       Running   0          9s
```

To see a more detailed description of what has happened behind the scenes:

```
ubuntu@node-21:~$ kubectl describe pod server-78k7k
Name:           server-78k7k
Namespace:      default
Node:           node-22/10.14.0.122
Start Time:     Tue, 14 Nov 2017 16:44:18 +0000
Labels:         role=server
Annotations:    kubernetes.io/created-by={"kind":"SerializedReference","apiVersion":"v1","reference":{"kind":"ReplicationController","namespace":"default","name":"server","uid":"0e9994a5-c95b-11e7-b620-525400a360c5",...
Status:         Running
IP:             192.168.73.8
Created By:     ReplicationController/server
Controlled By:  ReplicationController/server
Containers:
  server:
    Container ID:   docker://0eea5f5a80707a3f0e8a75d83550a874d95e01d5164df4258b4e803b4fabc520
    Image:          nginx
    Image ID:       docker-pullable://nginx@sha256:9fca103a62af6db7f188ac3376c60927db41f88b8d2354bf02d2290a672dc425
    Port:           <none>
    State:          Running
      Started:      Tue, 14 Nov 2017 16:44:26 +0000
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/lib/www/html from mypvc (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-qlskj (ro)
Conditions:
  Type           Status
  Initialized    True
  Ready          True
  PodScheduled   True
Volumes:
  mypvc:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  claim1
    ReadOnly:   false
  default-token-qlskj:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-qlskj
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.alpha.kubernetes.io/notReady:NoExecute for 300s
                 node.alpha.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason                 Age   From               Message
  ----    ------                 ----  ----               -------
  Normal  Scheduled              1m    default-scheduler  Successfully assigned server-78k7k to node-22
  Normal  SuccessfulMountVolume  1m    kubelet, node-22   MountVolume.SetUp succeeded for volume "default-token-qlskj"
  Normal  SuccessfulMountVolume  1m    kubelet, node-22   MountVolume.SetUp succeeded for volume "pvc-1ef00fd9-c95a-11e7-b620-525400a360c5"
  Normal  Pulling                1m    kubelet, node-22   pulling image "nginx"
  Normal  Pulled                 1m    kubelet, node-22   Successfully pulled image "nginx"
  Normal  Created                1m    kubelet, node-22   Created container
  Normal  Started                1m    kubelet, node-22   Started container
```
