## Creating and managing pods

At the core of Kubernetes is the Pod. Pods represent a logical application and hold a collection of one or more containers and volumes. In this section you will:

* Create a simple Hello World node.js application
* Create a docker container image
* Write a Pod configuration file
* Create and inspect Pods
* Interact with Pods remotely using kubectl

We'll create a Pod named `hello-world` and interact with it using the kubectl.

----

### Create your node.js app

A simple “hello world”: server.js (note the port number argument to www.listen):
```
var http = require('http');
var handleRequest = function(request, response) {
  response.writeHead(200);
  response.end("Hello World!");
}
var www = http.createServer(handleRequest);
www.listen(8080);
```

Save that to a file called `server.js`

----

### Create a docker container image

Create the file `Dockerfile` for hello-node (note port 8080 in the EXPOSE command):
```
FROM node:6.9
COPY server.js /
ENTRYPOINT ["node", "/server.js"]
EXPOSE 8080
```

----

### Build the container

We will build the container on minikube

```
docker build -t hello-node:v1 .
```

----

### Create your app on K8s

```
kubectl run hello-node --image=hello-node:v1 --port=8080
deployment "hello-node" created
```

----

### Check Deployment and Pod

```
kubectl get deployment
NAME         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
hello-node   1         1         1            1           49s

kubectl get pod
NAME                          READY     STATUS    RESTARTS   AGE
hello-node-2399519400-02z6l   1/1       Running   0          54s
```

----

### Check metadata about the cluster, events and kubectl configuration

```
kubectl cluster-info
kubectl get events
kubectl config view
```

----

### Creating a Pod manifest

Explore the `hello-world` pod configuration file:

```
cat pods/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-node
  labels:
    app: hello-node
spec:
  containers:
    - name: hello-node
      image: hello-node:v1
      ports:
        - containerPort: 8080
```
Create the pod using kubectl:

```
kubectl delete deployment hello-node
kubectl create -f pods/pod.yaml
```

----

### View Pod details

Use the `kubectl get` and `kubect describe` commands to view details for the `hello-node` Pod:

```
kubectl get pods
```

```
kubectl describe pods <pod-name>
```

----

### Interact with a Pod remotely

Pods are allocated a private IP address by default and cannot be reached outside of the cluster. Use the `kubectl port-forward`, as allreday done in the previous section, to map a local port to a port inside the `hello-node` pod.

Use two terminals. One to run the `kubectl port-forward` command, and the other to issue `curl` commands.

----

Terminal 1
```
kubectl port-forward hello-node 8080 8080
```
Terminal 2
```
curl 0.0.0.0:8080
Hello World!
```

----

### Debugging

### View the logs of a Pod

Use the `kubectl logs` command to view the logs for the `<PODNAME>` Pod:

```
kubectl logs <PODNAME>
```

> Use the -f flag and observe what happens.

----

### Run an interactive shell inside a Pod

Like with Docker you can establish an interactive shell to a pod with almost the same sytax. Use the `kubectl exec` command to run an interactive shell inside the `<PODNAME>` Pod:

```
kubectl exec -ti <PODNAME> /bin/sh
```