#! /bin/bash
kubectl run hello-kubernetes --image=gcr.io/google_containers/echoserver:1.4 --port=8080