# MonteCarlo K8s Demo: Request & Limits en Kubernetes

Proyecto didáctico para demostrar el impacto de `requests` y `limits` en Kubernetes, usando un modelo de MonteCarlo para simular carga controlada de CPU y memoria, y monitoreo con Prometheus/Grafana y recomendaciones con KRR.

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
- **helm** >= 3.18
- **Docker** >= 24
- **KinD** >= 0.22
- **Java** 17 o 21 (para la app)
- **Prometheus** y **Grafana** (instalados vía Helm)
- **KRR** (Kubernetes Resource Recommender)

---

## Instalación y Ejecución

1. **Preparar scripts:**
   ```bash
   chmod +x k8s/init-cluster.sh
   chmod +x k8s/get_pods.sh
   ```

2. **Crear el clúster local con KinD:**
   ```bash
   ./k8s/init-cluster.sh
   ```
    - Este script crea el clúster con KinD, instala Prometheus y Grafana vía Helm, despliega los manifiestos de infraestructura y aplicación, y expone los servicios necesarios.

3. **Editar el metrics-server para permitir insecure-tls (requerido en KinD):**
   ```bash
   kubectl -n kube-system edit deployment metrics-server
   ```
   Agregar en `spec.template.spec.containers[0].args`:
   ```
   --kubelet-insecure-tls
   ```

4. **Ver pods y recursos:**
   ```bash
   ./k8s/get_pods.sh -n demo-limits
   ```

5. **Acceder a Grafana:**
    - [http://localhost:3000/](http://localhost:3000/)
    - Dashboards recomendados: ID **15760** (demo), **23638** (recursos generales).

6. **Revisar Prometheus:**
    - [http://localhost:9090/targets](http://localhost:9090/targets)

7. **Obtener recomendaciones con KRR:**
   ```bash
   krr simple --namespace demo-limits -p http://127.0.0.1:30900
   ```

---

## Estructura del Proyecto

- `src/`: Código fuente Java (Spring Boot, modelo MonteCarlo).
- `k8s/infra/`: Manifiestos para infraestructura (KinD, Service, ServiceMonitor).
- `k8s/app/`: Manifiestos de la aplicación para distintos escenarios de `requests` y `limits`.
- `k8s/init-cluster.sh`: Script para crear el clúster, instalar Prometheus/Grafana y desplegar la demo.
- `k8s/get_pods.sh`: Script para inspeccionar pods y recursos (acepta parámetros de `kubectl get pods`).

---

## Modelo MonteCarlo

El modelo de MonteCarlo estima el valor de PI mediante simulaciones aleatorias, generando puntos en un cuadrado y contando cuántos caen dentro de un círculo inscrito. En este proyecto, se usa para forzar uso de CPU y memoria, permitiendo observar el efecto de los recursos asignados en Kubernetes.

Para ejecutar este proyecto, inicia el escenario deseado con:

```bash
kubectl apply -f k8s/app/<escenario>.yaml
```

Por ejemplo:

- `00-montecarlo-norequest-nolimits.yaml`: manifiesto sin `requests` ni `limits`.
- `01-montecarlo-request.yaml`: manifiesto con solo `requests`.
- `02-montecarlo-limits.yaml`: manifiesto con solo `limits`.
- `03-montecarlo-request-limits.yaml`: manifiesto con ambos, `requests` y `limits`.
- `04-montecarlo-guaranteed.yaml`: manifiesto para QoS `Guaranteed`.

Cada archivo permite observar el comportamiento de la aplicación bajo diferentes configuraciones de recursos en Kubernetes.

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

- Comando:
  ```bash
  krr simple --namespace demo-limits -p http://127.0.0.1:30900
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
- Ver targets de Prometheus:
    - [http://localhost:9090/targets](http://localhost:9090/targets)
- Inspeccionar pods y recursos:
  ```bash
  ./k8s/get_pods.sh -n demo-limits
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