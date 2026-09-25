# Estrategia de Escalado de Infraestructura - Orbit

Este documento describe la hoja de ruta técnica y arquitectónica para escalar la plataforma **Orbit** desde su fase inicial de costo mínimo hasta una infraestructura de alta disponibilidad distribuida globalmente con soporte masivo para WebRTC (Mediasoup).

---

## 1. Etapa Actual (V1 - Monolito Contenerizado de Bajo Costo)

```
[Usuario Web / Móvil]
         │
         ├── HTTPS / WSS (80, 443) ──> [ Nginx Reverse Proxy (SSL) ] ──> [ Orbit Backend (Node.js) ]
         │                                                                             │
         └── RTP / RTCP (UDP 10000-10100) ─────────────────────────────> [ Mediasoup SFU ]
                                (Elastic IP Dedicada en EC2)
```

- **Infraestructura:**
  - 1 Instancia EC2 (`t3.small` / `t3.medium`) en Default VPC con Elastic IP pública estática.
  - Orquestación con Docker Compose (Nginx + Backend Node.js / Mediasoup).
  - Base de datos MongoDB en clúster externo (MongoDB Atlas M0/M10).
- **Capacidad estimada:** 100 a 300 conexiones simultáneas / 10 a 20 salas activas.
- **Coste mensual estimado:** ~$18 - $25 USD.
- **Ventajas:** Cero sobrecostes de infraestructura (sin balanceadores ni clústeres gestionados), latencia mínima directa y despliegue rápido.

---

## 2. Etapa 2 (Escalado Vertical y Desacoplamiento de Servicios)

Cuando el tráfico comience a demandar mayor CPU para la codificación/reenvío de streams de Mediasoup:

- **Cambio de Familia de Instancia:**
  - Migrar la EC2 a una familia optimizada para cómputo: `c6i.large` (2 vCPU, 4 GB RAM) o `c6i.xlarge` (4 vCPU, 8 GB RAM). Mediasoup aprovecha directamente cada vCPU asignando un *Worker* por núcleo.
- **Almacenamiento Estático y Medios:**
  - Bucket S3 para archivos subidos por los usuarios (fotos de perfil, grabaciones) servidos mediante **Amazon CloudFront CDN** (Issue Orbit-0013 y Orbit-0014).
- **Capacidad estimada:** 500 a 1,500 streams simultáneos.
- **Coste mensual estimado:** ~$45 - $90 USD.

---

## 3. Etapa 3 (Escalado Horizontal y Alta Disponibilidad - Nivel Producción)

Para eliminar el punto único de fallo (SPOF) y soportar miles de participantes concurrentes en diferentes regiones geográficas:

```
                              [ Clientes Web / Móvil ]
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │ HTTPS / WebSocket (Capa 7)                    │ RTP/RTCP WebRTC (UDP)
                 ▼                                               ▼
       [ Application Load Balancer ]                   [ Network Load Balancer (NLB) ]
                 │                                               │
       ┌─────────┴─────────┐                           ┌─────────┴─────────┐
       ▼                   ▼                           ▼                   ▼
 [ API Node 1 ]      [ API Node 2 ]              [ Media SFU 1 ]     [ Media SFU 2 ]
   (ECS Fargate / EC2 Auto Scaling)                (EC2 Workers dedicados con Mediasoup)
       │                   │                                   ▲           ▲
       └─────────┬─────────┘                                   │           │
                 │                                             └─── Pipe ──┘
                 ▼                                              Transports
        [ Redis ElastiCache ]
   (Pub/Sub, Socket.io Adapter, Estado de Salas)
```

### Componentes Clave de la Etapa 3:

1. **Separación del Plano de Señalización y el Plano Multimedia:**
   - **Plano de Señalización (REST API y WebSockets):** Se traslada a contenedores sin estado (*stateless*) en **AWS ECS Fargate** o Auto Scaling Group de EC2, balanceados por un **Application Load Balancer (ALB)** con certificados automáticos de AWS Certificate Manager (ACM).
   - **Plano Multimedia (SFU Mediasoup):** Conjunto de instancias EC2 optimizadas para red y cómputo (`c6in.xlarge` con interfaces de red de 25 Gbps) detrás de un **Network Load Balancer (NLB)** o con IPs elásticas por nodo.

2. **Capa de Sincronización y Estado (Redis ElastiCache):**
   - Implementar un clúster de **Redis** como adapter de `socket.io-redis` para compartir salas y mensajes de chat entre todos los nodos de la API.
   - Registro de presencia y catálogo de enrutamiento (*Router mapping*) para saber qué nodo SFU alberga a cada emisor/receptor.

3. **Interconexión de SFUs (Mediasoup PipeTransports):**
   - Si el participante A está conectado al nodo SFU 1 y el participante B al nodo SFU 2, los routers de Mediasoup establecen un `PipeTransport` interno punto a punto para transferir el stream de video de un nodo al otro de manera transparente y con ultra baja latencia.

4. **Enrutamiento Inteligente por Latencia (Amazon Route 53):**
   - Políticas de enrutamiento geográfico o por menor latencia (*Latency-based routing*) para dirigir a los usuarios al centro de datos de AWS más próximo (ej. `us-east-1`, `us-east-2`, `sa-east-1` en São Paulo).

---

## 4. Cuadro Comparativo de Etapas

| Criterio | Etapa 1 (Actual) | Etapa 2 (Vertical) | Etapa 3 (Horizontal Distribuido) |
|---|---|---|---|
| **Cómputo** | 1x EC2 `t3.small` | 1x EC2 `c6i.large` | ECS Fargate + Pool EC2 `c6i` |
| **Balanceador** | Ninguno (Nginx local) | Ninguno (Nginx local) | ALB (HTTP/WS) + NLB (UDP) |
| **Estado / Cache** | Memoria local Node.js | Memoria local Node.js | Amazon ElastiCache (Redis) |
| **Punto Único de Fallo** | Sí | Sí | No (Redundante y Auto-escalable) |
| **Tráfico Mediasoup** | Local en un worker pool | Multi-core vertical | Distribuido con PipeTransports |
| **Capacidad Aprox.** | ~200 usuarios | ~1,500 usuarios | 10,000+ usuarios |
| **Coste Estimado** | ~$20 USD/mes | ~$60 USD/mes | ~$200 - $450 USD/mes |
