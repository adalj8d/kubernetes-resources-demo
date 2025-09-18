#!/bin/bash
set -euo pipefail

ns_demo_limits="demo-limits"
ns_monitoring="monitoring"
cluster_name="demo-cluster"
image="adalj8d/demo-limits:1.0.0"

# Crear el clúster KinD con configuración custom
kind create cluster --config infra/kind-cluster.yaml --name $cluster_name

echo "📦 Creando namespaces..."
kubectl create namespace "$ns_demo_limits" || echo "⚠️ Namespace $ns_demo_limits ya existe"
kubectl create namespace "$ns_monitoring" || echo "⚠️ Namespace $ns_monitoring ya existe"

echo "📥 Instalando kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "$ns_monitoring" \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30900 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300

echo -e "\n\n"

kubectl get svc -n "$ns_monitoring"

echo "📥 Instalando metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo -e "\n⏳ Esperando que los pods de monitoring estén listos (timeout 180s)..."
kubectl wait --for=condition=Ready pods --all -n "$ns_monitoring" --timeout=180s || {
  echo -e "\n\n⚠️  Algunos pods no se iniciaron. Verificar con: kubectl get pods -n $ns_monitoring"
}

#echo "🚀 Creando el Service y ServiceMonitor de MonteCarlo..."
#kubectl apply -f infra/montecarlo-service.yaml -n "$ns_demo_limits"
#kubectl apply -f infra/montecarlo-servicemonitor.yaml -n "$ns_demo_limits"

echo "⤴️ Cargando imagen Docker en el clúster KinD..."
kind load docker-image $image --name $cluster_name

echo -e "\n✅ Clúster inicializado correctamente.\n\n"
echo "👉 Prometheus disponible en NodePort 30900, accesible a traves de KinD http://localhost:9090"
echo "👉 Grafana disponible en NodePort 30300, accesible a traves de KinD http://localhost:3000 admin/$(kubectl --namespace monitoring get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo)"

echo -e "\n\n‼️edite manualmente: kubectl -n kube-system edit deployment metrics-server\n spec.template.spec.containers[0].args: - --kubelet-insecure-tls\n"
