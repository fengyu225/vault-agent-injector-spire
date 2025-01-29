#!/bin/bash

# Get PostgreSQL container IP from the kind network
POSTGRES_IP=$(docker inspect -f '{{range $network, $conf := .NetworkSettings.Networks}}{{if eq $network "kind"}}{{$conf.IPAddress}}{{end}}{{end}}' app-db)

# Create namespace
kubectl create namespace app

# Replace POSTGRES_IP in the yaml and apply
sed "s/POSTGRES_IP/$POSTGRES_IP/" postgres-endpoint.yaml | kubectl apply -f -

# Verify the endpoint
kubectl get endpoints -n app postgres