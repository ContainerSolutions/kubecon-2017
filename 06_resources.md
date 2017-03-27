### Resource Management

In this section we'll discuss about:
* QoS
* Resource Quotas

----

### The resource model

What exactly is a resource in Kubernetes?

CPU & Memory
* Accounted
* Scheduled
* Isolated
Local Storage (Disk or SSD)
* Accounted (restriction to single partition /)
Nvidia GPU
* Alpha support (1 GPU per-node)

----

### Requests and Limits

Request: (soft limit)
How much of a resource a container is asking to use with a strong guarantee of availability
* CPU (millicores, 1/1000 of one core)
* RAM (bytes)
Scheduler will not over-commit requests
Limit: (hard limit)
* max amount of a resource a container can access
* scheduler ignores limits
Repercussions:
* Usage > Request: resources might be available
* Usage > Limit: killed or throttled

If a pod is successfully scheduled, the container is guaranteed the amount of resources requested. Scheduling is based on requests and not limits

----

### Setting resource limits

* Set resource request that Kubernetes can schedule containers on different instances to use as much potential capacity as possible. 
* Set resource limit that in the case you have a application trying eating up all ressources (java :-)), it can be prevented.

This is why you should ALWAYS set both resource requests and resource limits.

----

### Compressible Resource Guarantees

Kubernetes only supports CPU at the moment

* Pods are guaranteed to get the amount of CPU they request
* This isn't fully guaranteed today because cpu isolation is at the container level. Pod level cgroups will be introduced soon to achieve this goal.
* Excess CPU resources will be distributed based on the amount of CPU requested. 

----

Example (1 vCPU available): 
* Container A requests 600 milli CPUs
* Container B requests for 300 milli CPUs
* Both containers trying to use as much CPU as they can. Then the extra 100 milli CPUs will be distributed to A and B in a 2:1 ratio

Pods will be throttled if they exceed their limit. If limit is unspecified, then the pods can use excess CPU when available.

----

### Incompressible Resource Guarantees

Kubernetes only supports memory at the moment

* Pods will get the amount of memory they request, if they exceed they could be killed (if some other pod needs memory)
* If pods consume less memory than requested, they will not be killed (except in cases where system tasks or daemons need more memory)

When Pods use more memory than their limit, a process that is using the most amount of memory, inside one of the pod's containers, will be killed by the kernel.


----

### Quality of Service Classes
Guaranteed: highest protection
* request > 0 && limit == request

- If `limits` and optionally `requests` (not equal to `0`) are set for all resources across all containers and they are *equal*, then the pod is classified as **Guaranteed**.

----

Best Effort: lowest protection
• request == 0 (limit == node size)

- If `requests` and `limits` are not set for all of the resources, across all containers, then the pod is classified as **Best-Effort**.

----

Burstable: medium protection
• request > 0 && limit > request

- If `requests` and optionally `limits` are set (not equal to `0`) for one or more resources across one or more containers, and they are *not equal*, then the pod is classified as **Burstable**.

----

How is “protection” implemented?
* CPU: some Best Effort/Burstable container using more than its request is throttled
    * CPU shares + CPU quota
* Memory: some Best Effort/Burstable container using more than its request is killed
    * OOM score + user-space evictions

----

### Examples

CPU requests are used at schedule time, and represent a minimum amount of CPU that should be reserved for your container to run.

Let's demonstrate this concept using a simple container that will consume as much CPU as possible.
```
kubectl run cpustress --image=busybox --requests=cpu=100m \
	-- md5sum /dev/urandom
```
This will create a single pod on your node that requests 1/10 of a CPU, but it has no limit on how much CPU it may actually consume on the node.

----

To demonstrate this, you can use `kubectl top pod <PODNAME>` to view the the used CPU shares

```
kubectl top pod cpustress-4101692926-zqw2p
NAME                         CPU(cores)   MEMORY(bytes)   
cpustress-4101692926-zqw2p   924m         0Mi             
```

As you can see it uses 924m of a 1vCPU machine

----

If you scale your application, we should see that each pod is given an equal proportion of CPU time.

```
kubectl scale deployment cpustress --replicas=3
```
Once all the pods are running, you will see that each pod is getting approximately an equal proportion of CPU time.

```
kubectl top pod
NAME                         CPU(cores)   MEMORY(bytes)   
cpustress-4101692926-1svfw   324m         0Mi             
cpustress-4101692926-9gkd1   322m         0Mi             
cpustress-4101692926-zqw2p   326m         0Mi       
```

Each container is getting 30% of the CPU time per their scheduling request, and we are unable to schedule more.

----

### Cleanup

```
kubectl delete deployment cpustress
```

----

### CPU limit

Setting a limit will allow you to control the maximum amount of CPU that your container can burst to.

```
kubectl run cpustress --image=busybox --requests=cpu=100m \
--limits=cpu=200m -- md5sum /dev/urandom
```

You can verify that by using `kubectl top`
```
kubectl top pod
NAME                         CPU(cores)   MEMORY(bytes)   
cpustress-1437538636-wkzh7   199m         0Mi             
```

----

If you scale your application, we should see that each pod is consuming a maximum of 200m CPU shares.

```
kubectl scale deployment cpustress --replicas=3
```
Once all the pods are running, you will see that each pod is getting approximately an equal proportion of CPU time.

```
kubectl top pod
NAME                         CPU(cores)   MEMORY(bytes)   
cpustress-1437538636-16j24   197m         0Mi             
cpustress-1437538636-wkzh7   199m         0Mi             
cpustress-1437538636-bcfh4   201m         0Mi
```

----

### Memory requests

By default, a container is able to consume as much memory on the node as possible. It is recommended to specify the amount of memory your container will require to run.

We'll allocate and write 200MB of memory every 2s.

```
kubectl run memhog --image=derekwaynecarr/memhog --requests=memory=100Mi \
--command -- /bin/sh -c "while true; do memhog -r100 200m; sleep 1; done"
```
Verify the usage with `kubectl top pod``
````
kubectl top pod
NAME                     CPU(cores)   MEMORY(bytes)   
memhog-328396322-dh03t   772m         200Mi    
```

We request 100Mi, but have burst our memory usage to a greater value. That's called Burstable.

----

### Memory limits

If you specify a memory limit, you can constrain the amount of memory your container can use.

For example, let's limit our container to 200Mi of memory, and just consume 100MB

```
kubectl run memhog --image=derekwaynecarr/memhog --limits=memory=200Mi \
--command -- /bin/sh -c "while true; do memhog -r100 100m; sleep 1; done"
```

```
kubectl top pod
NAME                      CPU(cores)   MEMORY(bytes)   
memhog-4201114837-svfjl   632m         100Mi     
```
As you can see we are only consuming 100MB on the node.

----

### Exceeding the limit

Let's create a deployment whose pod will keep being OOM killed because it attempts to allocate 300MB of memory, but is limited to 200Mi.

```
kubectl run memhog-oom --image=derekwaynecarr/memhog --limits=memory=200Mi \
--command -- memhog -r100 300m
```

----

If we describe the created pod, you will see that it keeps restarting until it goes into a CrashLoopBackOff.


```
kubectl get po
NAME                          READY     STATUS      RESTARTS   AGE
memhog-4201114837-svfjl       1/1       Running     0          11m
memhog-oom-3179143800-gmdbc   0/1       OOMKilled   5          3m
kubectl describe po memhog-oom-3179143800-gmdbc |grep -C 3 "Terminated"
      memory:		200Mi
    State:		Waiting
      Reason:		CrashLoopBackOff
    Last State:		Terminated
      Reason:		OOMKilled
      Exit Code:	137
      Started:		Mon, 20 Mar 2017 22:51:57 +0100

```

----

### What if my node runs out of memory?

With Guaranteed resources you are not in major danger of causing an OOM event on your node

If any individual container consumes more than their specified limit, it will be killed

----

With BestEffort and Burstable resources it is possible to overprovsion

If this happens: 
* the system will attempt to prioritize the containers that are killed based on their quality of service. 
* This is done by using the OOMScoreAdjust feature in the Linux kernel
* Processes with lower values are preserved in favor of processes with higher values. 
* The system daemons (kubelet, kube-proxy, docker) all run with low OOMScoreAdjust values.

----

Containers with Guaranteed memory are given a lower value than Burstable containers which has a lower value than BestEffort containers. As a consequence, containers with BestEffort should be killed before the others.

----

### Example (may lead to a unstable system)

```
kubectl run mem-guaranteed --image=derekwaynecarr/memhog --replicas=2 \
	--requests=cpu=10m --limits=memory=600Mi \
	--command -- memhog -r100000 500m
kubectl run mem-burstable --image=derekwaynecarr/memhog --replicas=2 \
	--requests=cpu=10m,memory=600Mi 
	--command -- memhog -r100000 100m
kubectl run mem-besteffort --replicas=10 --image=derekwaynecarr/memhog \
	--requests=cpu=10m --command -- memhog -r10000 500m
```
This will force a SystemOOM
```
kubectl get events | grep OOM
17s        17s         1         gke-cluster-1-default-pool-312d7520-c4db   Node                                           Warning   SystemOOM                 {kubelet gke-cluster-1-default-pool-312d7520-c4db}      System OOM encountered
```

Depending on how the host operating system is configured, and which process the Kernel ultimately decides to kill on your Node, you may experience unstable results.

----

### Resource Quota

Quotas can be set per-namespace
* maximum request and limit across all pods
* applies to each type of resource (CPU, mem)
* user must specify request or limit
* maximum number of a particular kind of object
Ensure no user/app/department abuses the cluster

Applied at admission time

Pods which specify explicitly resource limits and requests will not pick up the namespace default values.

----

Needs to be applied to a namespace
```
apiVersion: v1
kind: LimitRange
metadata:
  name: mylimits
spec:
  limits:
  - max:
      cpu: "2"
      memory: 1Gi
    min:
      cpu: 200m
      memory: 6Mi
    type: Pod
  - default:
      cpu: 300m
      memory: 200Mi
    defaultRequest:
      cpu: 200m
      memory: 100Mi
    max:
      cpu: "2"
      memory: 1Gi
    min:
      cpu: 100m
      memory: 3Mi
    type: Container
```

----

Create a namespace and apply the limits to that namespace

```
kubectl create namespace limit-example
kubectl create -f resources/limits.yaml --namespace limit-example
```
Create a deployment in that namespace
```
kubectl run nginx --image=nginx --replicas=1 --namespace=limit-example
deployment "nginx" created
```

----

The default values of the namespace limit will be applied to this pod

```
kubectl get po -n limit-example -o yaml
...
spec:
  containers:
  - image: nginx
    imagePullPolicy: Always
    name: nginx
    resources:
      limits:
        cpu: 300m
        memory: 200Mi
      requests:
        cpu: 200m
        memory: 100Mi
```

----

If we deploy a pod which exceeds the limit

```
apiVersion: v1
kind: Pod
metadata:
  name: invalid-pod
spec:
  containers:
  - name: kubernetes-serve-hostname
    image: gcr.io/google_containers/serve_hostname
    resources:
      limits:
        cpu: "3"
        memory: 100Mi
```
The output of kubectl is
```
kubectl create -f resources/invalid-cpu-pod.yaml -n limit-example
Error from server (Forbidden): error when creating "resources/invalid-cpu-pod.yaml": pods "invalid-pod" is forbidden: [maximum cpu usage per Pod is 2, but limit is 3., maximum cpu usage per Container is 2, but limit is 3.]
```

----

### Cleanup
```
kubectl delete -f resources/
```

----

In this section you learned what ressources are in Kubernetes, how limits can be applied and what QoS possibilities Kubernetes offers.