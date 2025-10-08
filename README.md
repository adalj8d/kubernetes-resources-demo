# MonteCarlo K8s Demo: Request & Limits en Kubernetes

Proyecto demo del impacto de `requests` y `limits` en Kubernetes.

Se utiliza un modelo de MonteCarlo para simular carga controlada de CPU y memoria.
El monitoreo a cargo de Prometheus/Grafana
Se utiliza la herramienta KRR para las recomendaciones.

---

## Índice

- [Epílogo](#epílogo)
- [Requisitos](#requisitos)
- [Instalación y Ejecución](#instalación-y-ejecución)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Modelo MonteCarlo](#modelo-montecarlo)
- [Monitoreo y Dashboards](#monitoreo-y-dashboards)
- [Kubernetes Resource Recommender (KRR)](#kubernetes-resource-recommender-krr)
- [Tips de Observabilidad](#tips-de-observabilidad)
- [Eliminación del Clúster](#eliminación-del-clúster)
- [Referencias](#referencias)
- [Otra Información Valiosa](#otra-información-valiosa)

---

## Epílogo

Este proyecto busca facilitar la comprensión y experimentación sobre cómo los recursos (`requests` y `limits`) afectan el comportamiento y la estabilidad de aplicaciones en Kubernetes. Permite observar el efecto de throttling, OOMKills y recomendaciones automáticas de recursos, ayudando a tomar decisiones informadas para ambientes productivos.

---

## Requisitos

- **kubectl** >= 1.33
- **kustomize** >= 5.7
- **helm** >= 3.18
- **Docker** >= 24
- **KinD** >= 0.22
- **Java** 17 o 21 (si se modificará la app)
- **Prometheus** y **Grafana** (instalados vía Helm)
- **Service Monitor** (instalados con Kustomize)
- **KRR** (Kubernetes Resource Recommender)

---

## Instalación y Ejecución

1. **Preparar scripts:**
   ```bash
   chmod +x k8s/init-cluster.sh
   chmod +x k8s/get_pods.sh
   ```

2. **Crear el clúster local con KinD:**

   - Este permite tener un cluster de kubernetes en local listo para trabajar. 
   - El script asigna "demo-limits" como default namespace
   - 

   ```bash
   ./k8s/init-cluster.sh
   ```
    - Este script crea el clúster con KinD, instala Prometheus y Grafana vía Helm, despliega los manifiestos de infraestructura y aplicación, y expone los servicios necesarios.
    - Si no se desea hacer cambios en el código ni publicar una imagen con cambios, se debe tener la imagen en local (el script lo descarga de hub.docker en caso no se cuente en local)
    - Si se desea realizar cambios en local, modifique, compile y cree la imagen con: ```mvn clean compile package docker:build ```. El fuente contiene lo necesario para empaquetar la imagen.
    - 

3. **Editar el metrics-server para permitir insecure-tls (requerido en KinD):**
   ```bash
   kubectl -n kube-system edit deployment metrics-server
   ```
   Agregar en `spec.template.spec.containers[0].args`:
   ```
   --kubelet-insecure-tls
   ```
   > **Nota:**  En esta versión se resuelve con kustomize con strategy `merge`. No es necesario editar manualmente.

   Comprobar que metrics server se puede visualizar:

   ```bash
   kubectl tops nodes
   kubectl top pods
   ```

4. **Ver pods y recursos:**
   Usar el script que facilita la inspección. Este script muestra los pods y sus recursos asignados y usados en formato de campos de la demostración y presentación
   ```bash
   ./k8s/get_pods.sh -n demo-limits
   ```

5. **Acceder a Grafana:**
    - [http://localhost:3000/](http://localhost:3000/)
    - Dashboards recomendados: ID **15760** (demo), **23638** (recursos generales).

6. **Información de Prometheus:**
    - [http://localhost:9090/targets](http://localhost:9090/targets)

7. **Obtener recomendaciones con KRR:**
   ```bash
   krr simple --namespace demo-limits -p http://127.0.0.1:30900
   ```

---

## Estructura del Proyecto

- `src/`: Código fuente Java (Spring Boot, modelo MonteCarlo).
- `k8s/infra/`: Manifiestos para infraestructura (KinD, Service, ServiceMonitor, kustomize de metrics-server) .
- `k8s/app/`: Manifiestos de la aplicación para distintos escenarios de `requests` y `limits`.
- `k8s/init-cluster.sh`: Script para crear el clúster, instalar Prometheus/Grafana y desplegar la demo.
- `k8s/get_pods.sh`: Script para inspeccionar pods y recursos (acepta parámetros de `kubectl get pods`).

---

## Simulaciones de escenarios

El modelo de MonteCarlo estima el valor de PI mediante simulaciones aleatorias, generando puntos en un cuadrado y contando cuántos caen dentro de un círculo inscrito. En este proyecto, se usa para forzar uso de CPU y memoria, permitiendo observar el efecto de los recursos asignados en Kubernetes.

Para ejecutar este proyecto, inicia el escenario deseado.  

!! RECORDAR SIEMPRE que en vez de kubectl get pods, está el script "./get_pods.sh" para obtener información relevante que se ha hablado durante la charla.

Las épicas sugeridas son:

### 1. Visualización de Dashboards

Para monitorear el comportamiento de los pods y el efecto de los recursos, utiliza los siguientes dashboards en Grafana (KinD):

- **Workloads:**  
  [kubernetes-compute-resources-workload](http://localhost:3000/d/a164a7f0339f99e89cea5cb47e9be617/kubernetes-compute-resources-workload?orgId=1&from=now-5m&to=now&timezone=America%2FBogota&var-datasource=default&var-cluster=&var-namespace=&var-type=$__all&var-workload=&refresh=5s)

- **Namespace Workloads:**  
  [kubernetes-compute-resources-namespace-workloads](http://localhost:3000/d/a87fb0d919ec0ea5f6543124e16c42a5/kubernetes-compute-resources-namespace-workloads?orgId=1&from=now-5m&to=now&timezone=America%2FBogota&var-datasource=default&var-cluster=&var-namespace=&var-type=$__all&refresh=5s)

- **Pod (Throttling):**  
  [kubernetes-compute-resources-pod](http://localhost:3000/d/6581e46e4e5c7ba40a07646395ef7b23/kubernetes-compute-resources-pod?orgId=1&from=now-5m&to=now&timezone=America%2FBogota&var-datasource=default&var-cluster=&var-namespace=default&var-pod=&refresh=5s)

> **Nota:** Selecciona el namespace correcto para visualizar los pods de la demo.

---

### 2. Escenario 1: Sin quotas, uso libre

Despliega el modelo sin restricciones de recursos:

```bash
kubectl apply -f k8s/app/10-montecarlo-norequest-nolimits.yaml
```

Escala el deployment para aumentar la carga:

```bash
kubectl scale --replicas=2 deployment montecarlo0
```

Observa en el dashboard que no hay throttling ni quotas aplicadas.  
Monitorea los logs y el tiempo de cálculo de MonteCarlo:

```bash
kubectl stern montecarlo0
```

---

### 3. Eliminar el deployment creado

Elimina el escenario anterior para limpiar el entorno:

```bash
kubectl delete -f k8s/app/10-montecarlo-norequest-nolimits.yaml
```

---

### 4. Crear una quota y ejecutar nuevamente el modelo

Aplica una quota de recursos al namespace:

```bash
kubectl apply -f k8s/app/00-montecarlo-resourcequota.yaml
```

Consulta la quota creada:

```bash
kubectl get quota
kubectl describe quota
```

Vuelve a desplegar el modelo sin restricciones:

```bash
kubectl apply -f k8s/app/10-montecarlo-norequest-nolimits.yaml
```

Observa el resultado con el script de inspección:

```bash
./k8s/get_pods.sh
```

Si el pod no se crea, verifica los eventos para entender el motivo:

```bash
kubectl get events
```

> Más información: [Resource Quotas en Kubernetes](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

---

### 5. Crear un despliegue limitado

Aplica un manifiesto con `requests` y `limits` iguales:

```bash
kubectl apply -f k8s/app/11-montecarlo-request-limits-equals.yaml
```

Visualiza el dashboard de throttling (selecciona el pod `montecarlo1-xxx`).  
Monitorea el tiempo de cálculo y el efecto del throttling:

```bash
kubectl stern montecarlo1
```

---

### 6. Escenario: Crear el recurso 12-montecarlo y examinar por qué no se crea

Aplica el manifiesto con solo `requests`:

```bash
kubectl apply -f k8s/app/12-montecarlo-request-only.yaml
```

Inspecciona los pods:

```bash
./k8s/get_pods.sh
```

> La creación depende de la configuración de la quota y los recursos disponibles.

---

### 7. Crear el manifiesto 13-x y observar el límite

Aplica el manifiesto estando cerca del límite de quota:

```bash
kubectl apply -f k8s/app/13-montecarlo-guaranteed.yaml
```

Describe la quota y verifica el estado de los pods:

```bash
kubectl describe quota
./k8s/get_pods.sh
```

---

### 8. Crear el manifiesto 14-x y observar el efecto de los límites

Aplica el manifiesto con `requests` y `limits` diferentes:

```bash
kubectl apply -f k8s/app/14-montecarlo-request-limits-diff.yaml
```

Si el pod no se crea, verifica el motivo:

```bash
./k8s/get_pods.sh
```

El error típico es:

```
is forbidden: exceeded quota: montecarlo-resourcequota
```

Edita la quota si es necesario:

```bash
kubectl edit quota
```

Espera unos minutos, observa la creación del pod, la QoS y la prioridad.  
Escala el deployment para llegar al límite:

```bash
kubectl scale --replicas=2 deployment montecarlo4
```

---

### 9. Eliminar la quota y aplicar el escenario 15-x

Elimina la quota para liberar recursos:

```bash
kubectl delete -f k8s/app/00-montecarlo-resourcequota.yaml
```

Aplica el siguiente escenario y observa con `-w` en el script `get_pods` para observar la falla por memoria.

```bash
kubectl apply -f k8s/app/15-montecarlo-OOMKill.yaml
```

---

Estos pasos permiten observar el comportamiento de la aplicación bajo diferentes configuraciones de recursos, quotas y políticas de Kubernetes, facilitando la comprensión de los conceptos de throttling, OOMKills y QoS.

---

## Monitoreo y Dashboards

- **Grafana:** [http://localhost:3000/](http://localhost:3000/)
    - Dashboard principal: **ID 15760**
    - Dashboard alternativo: **ID 23638**
    - Dashboards por defecto de Helm muestran Throttling y OOMKills.

- **Prometheus:** [http://localhost:9090/targets](http://localhost:9090/targets)

---

## Kubernetes Resource Recommender (KRR)

KRR analiza el uso histórico de recursos y recomienda valores óptimos de `requests` y `limits` para cada pod.

En este ejemplo, si el cluster fue creado de 0, no se cuenta con suficiente información para recomendación, por lo que se disminuye los porcentajes y percentiles para ejecutar y obtener alguna recomendación (para efectos de demostración de uso de KKR):

- Comando sugerido cuando no existen métricas suficientes:
  ```bash
  krr simple --namespace demo-limits -p http://localhost:9090 --cpu_percentile=90 --memory_buffer_percentage=15 --history_duration=1 --timeframe_duration=0.1
  ```

- [KRR GitHub](https://github.com/robusta-dev/krr?tab=readme-ov-file#usage)

---

## Tips de Observabilidad

- Ver consumo por nodo:
  ```bash
  kubectl top nodes
  ```
- Ver consumo por pod:
  ```bash
  kubectl top pods -n demo-limits
  ```

---

## Eliminación del Clúster

```bash
kind delete cluster --name demo-cluster
```

---

## Referencias

| Título | Link |
|--------|------|
| KRR Usage | [https://github.com/robusta-dev/krr?tab=readme-ov-file#usage](https://github.com/robusta-dev/krr?tab=readme-ov-file#usage) |
| Kubernetes v1.34 Release | [https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-release/#in-place-pod-resize-improvements](https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-release/#in-place-pod-resize-improvements) |
| Resize Container Resources | [https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/](https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/) |
| Grafana CPU Throttling | [https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/optimize-resource-usage/cpu-throttling/](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/optimize-resource-usage/cpu-throttling/) |
| Limit Range | [https://kubernetes.io/docs/concepts/policy/limit-range/](https://kubernetes.io/docs/concepts/policy/limit-range/) |
| Resource Quotas | [https://kubernetes.io/docs/concepts/policy/resource-quotas/](https://kubernetes.io/docs/concepts/policy/resource-quotas/) |
| Grafana Dashboards Kubernetes | [https://github.com/dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes) |
| Medium: Grafana Dashboards | [https://medium.com/@dotdc/an-updated-set-of-grafana-dashboards-for-kubernetes-f5d6e4ff5072](https://medium.com/@dotdc/an-updated-set-of-grafana-dashboards-for-kubernetes-f5d6e4ff5072) |

---

## Otra Información Valiosa

- Los manifiestos en `k8s/app/` permiten probar distintos escenarios de QoS (`BestEffort`, `Burstable`, `Guaranteed`).
- El script `init-cluster.sh` automatiza la creación del clúster, despliegue de la demo y monitoreo.
- El script `get_pods.sh` facilita la inspección de recursos y puede recibir parámetros como `-w` o `-n`.
- El modelo MonteCarlo es configurable en número de simulaciones, memoria y duración, permitiendo observar el impacto real de los recursos asignados.
- Los dashboards de Grafana pueden ser exportados/importados para facilitar la visualización en otros entornos.
- El monitoreo con Prometheus y Grafana permite identificar fácilmente problemas de throttling y OOMKills.
- El proyecto es ideal para capacitaciones, pruebas de laboratorio y benchmarking de recursos en Kubernetes.

---

¡Explora, experimenta y aprende sobre la gestión eficiente de recursos en Kubernetes!