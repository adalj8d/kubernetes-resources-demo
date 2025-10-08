#!/bin/bash
set -euo pipefail

ns_demo_limits="demo-limits"
ns_monitoring="monitoring"
cluster_name="demo-cluster"
image="adalj8d/demo-limits:1.0.0"

# Crear el clúster KinD con configuración custom
kind create cluster --config infra/kind-cluster.yaml --name $cluster_name

echo -e "\n🔄 Cambiando contexto kubectl al clúster $cluster_name...\n"
kubectl config use-context kind-$cluster_name

echo -e "\n📦 Creando namespaces... \n"
kubectl create namespace "$ns_demo_limits" || echo "⚠️ Namespace $ns_demo_limits ya existe"
kubectl create namespace "$ns_monitoring" || echo "⚠️ Namespace $ns_monitoring ya existe"

echo -e "\n🔄 Cambiando namespace por defecto a $ns_demo_limits..."
kubectl config set-context --current --namespace=$ns_demo_limits

echo -e "\n📥 Instalando kube-prometheus-stack...\n"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "$ns_monitoring" \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30900 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300 2>&1 | grep -v "Warning:" || true

echo -e "\n\n"

echo -e "📥 Instalando metrics-server... con patch de certificado autofirmado (cluster local)\n"
#kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -k infra/metrics-server/

echo -e "\n\n⏳ Esperando que los pods de monitoring estén listos (timeout 180s)...\n\n"
kubectl wait --for=condition=Ready pods --all -n "$ns_monitoring" --timeout=180s || {
  echo -e "\n\n⚠️  Algunos pods no se iniciaron. Verificar con: kubectl get pods -n $ns_monitoring"
}

#AGREGA CONDICION PARA VERIFICAR SI LA IMAGEN EXISTE LOCALMENTE
echo -e "\n🔍 Verificando si la imagen Docker $image existe localmente..."

if [[ "$(docker images -q $image 2> /dev/null)" == "" ]]; then
  docker pull $image || {
    echo -e "\n\n❌ Error: La imagen $image no existe localmente y no se pudo descargar. Verificar el nombre de la imagen correcta"
    exit 1
  }
fi

echo -e "\n\n⤴️ Cargando imagen Docker en el clúster KinD..."
kind load docker-image $image --name $cluster_name || {
  echo -e "\n\n❌ Error cargando la imagen $image en el clúster KinD. Verificar que la imagen exista localmente con 'docker images'. o tener acceso desde el cluster a docker hub"
}

echo -e "\n\n📦 Desplegando service monitor \n"
kubectl apply -f infra/montecarlo-service.yaml -f infra/montecarlo-servicemonitor.yaml

echo -e "\n\n📦 Creando priority classes \n"
kubectl apply -f app/01-priority-classes.yaml

echo -e "\n✅ Clúster inicializado correctamente.\n\n"
echo "👉 Prometheus disponible en NodePort 30900, accesible a traves de KinD http://localhost:9090"
echo "👉 Grafana disponible en NodePort 30300, accesible a traves de KinD http://localhost:3000 admin/$(kubectl --namespace monitoring get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo)"

echo "👉 Namespace por defecto cambiado a $ns_demo_limits. Use 'kubectl config set-context --current --namespace=default' para volver a default."
echo "👉 Context actual: $(kubectl config current-context)"
echo -e "\n\n🚀 Listo para usar el clúster. ¡Manos a la obra!"