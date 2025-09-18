#!/bin/bash

# Verifica si kubecolor está disponible
if command -v kubecolor &> /dev/null
then
    KUBE_CMD="kubecolor"
else
    KUBE_CMD="kubectl"
fi

# Argumentos adicionales pasados al comando kubectl como "-w" para watch o "-n <namespace>"
ADDITIONAL_ARGS="$@"

# Ejecuta el comando con kubecolor o kubectl según corresponda y pasa los argumentos adicionales
$KUBE_CMD get pods -o custom-columns="NODE:.spec.nodeName,NAME:.metadata.name,IMAGE:.spec.containers[0].image,IP:.status.podIP,RequestCPU:.spec.containers[0].resources.requests.cpu,LimitCPU:.spec.containers[0].resources.limits.cpu,RequestMem:.spec.containers[0].resources.requests.memory,LimitMem:.spec.containers[0].resources.limits.memory,QoS:.status.qosClass,Priority:.spec.priority,PreemptionPolicy:.spec.preemptionPolicy,AllocatedCPU:.status.containerStatuses[0].allocatedResources.cpu,AllocatedMem:.status.containerStatuses[0].allocatedResources.memory" $ADDITIONAL_ARGS

