#!/bin/bash
while [[ $(kubectl get pods -n test-its-k8s -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 1
done

