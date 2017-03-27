## Creating and Managing Services

In this section you will create the `hello-node` service and "expose" the `hello-node` Pod. You will learn how to:

* Create a service
* Use label and selectors to expose a limited set of Pods externally

----

### Introduction to services
Services provide stable endpoints for Pods based on a set of labels and selectors.

Some of the service types are:
* `ClusterIP` Your service is only expose internally to the cluster on the internal cluster IP. A example would be to deploy Hasicorp’s vault and expose it only internally.

* `NodePort` Expose the service on the instances on the specified or random assigned port.

----

* `LoadBalancer` Supported on e.g. Amazon and Google cloud, this creates load balancer VIP

* `ExternalName` Create a CNAME dns record to a external domain.

For more information about Services look at https://kubernetes.io/docs/user-guide/services/

----

### Create a Service

Explore the hello-node service configuration file:

```
cat services/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-node
spec:
  type: NodePort
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
    nodePort: 30080
  selector:
    app: hello-node
```

type: NodePort is needed as we don't have a integrated loadbalancer. We assign a static high-port for having consistency in this doc.

----

Create the hello-node service using kubectl:

```
kubectl create -f services/service.yaml
```

Interact with the hello-node Service Remotely

```
curl -i 0.0.0.0:30080
```

----

### Explore the hello-node Service

```
kubectl get services hello-node
```

```
kubectl describe services hello-node
```

----

### Using and adding labels to Pods

One way to troubleshoot an issue is to use the `kubectl get pods` command with a label query.

```
kubectl get pods -l "app=hello-node"
```

With the `kubectl label` command you can add labels like `secure=disabled` to a Pod.

```
kubectl label pods hello-node 'secure=disabled'
```