# Vastra Product Service

## Overview
The **Product Service** is a Node.js/Express microservice responsible for managing the product catalog (CRUD operations, categories) in the VastraCo e-commerce platform.

| Property | Value |
|----------|-------|
| **Runtime** | Node.js 20 (Alpine) |
| **Framework** | Express.js |
| **Port** | 3002 |
| **Database** | PostgreSQL (`products_db` / `products_db_main`) |
| **Docker Image** | `harshithasrinivas03/product-service` |

---

## Repository Structure
```
Vastra-product-service/
├── .github/workflows/
│   └── ci.yml                    # CI trigger — calls reusable template
├── src/
│   ├── server.js                 # Express app entry point
│   ├── db/index.js               # PostgreSQL connection pool + schema init
│   ├── controllers/
│   │   └── productController.js  # Product CRUD handlers
│   ├── models/
│   │   └── productModel.js       # DB queries
│   ├── routes/
│   │   └── productRoutes.js      # /api/products/* route definitions
│   └── __tests__/                # Unit tests (Jest)
├── Dockerfile                    # Multi-stage Docker build
├── package.json
└── README.md
```

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/products` | No | List all products |
| GET | `/api/products/:id` | No | Get product by ID |
| POST | `/api/products` | Bearer JWT | Create a product |
| PUT | `/api/products/:id` | Bearer JWT | Update a product |
| DELETE | `/api/products/:id` | Bearer JWT | Delete a product |
| GET | `/api/categories` | No | List categories |
| GET | `/health` | No | Liveness probe |
| GET | `/ready` | No | Readiness probe (checks DB) |

---

## Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `PORT` | Helm Deployment | Service port (3002) |
| `NODE_ENV` | ConfigMap | Environment (`dev` / `main`) |
| `PRODUCT_DB_HOST` | ConfigMap | PostgreSQL host (K8s DNS) |
| `PRODUCT_DB_PORT` | ConfigMap | PostgreSQL port (5432) |
| `PRODUCT_DB_NAME` | ConfigMap | Database name |
| `PRODUCT_DB_USER` | SealedSecret (`products-db-secret`) | DB username |
| `PRODUCT_DB_PASSWORD` | SealedSecret (`products-db-secret`) | DB password |

---

## CI/CD Pipeline

### Trigger
```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
```

### Pipeline Flow
```
ci.yml (this repo) ──calls──► ci-template.yml (Reusable-template repo)

Prepare → Test → SonarQube → Snyk → Docker Build → Trivy → Docker Push → Update Helm → Release → Notify
```

### Branch-Based Deployment
| Branch | Values File | K8s Namespace | Environment |
|--------|-------------|---------------|-------------|
| `main` | `values-main.yaml` | `main` | Production |
| `develop` | `values-dev.yaml` | `dev` | Development |

---

## Dockerfile — Multi-Stage Build
```
Stage 1 (builder): node:20-alpine
  → Install build tools (python3, make, g++)
  → npm install
  → Patch vulnerabilities: cross-spawn@7.0.5, glob@10.5.0, minimatch@9.0.7

Stage 2 (runtime): node:20-alpine
  → Copy node_modules from builder
  → Copy source code
  → EXPOSE 3002
  → CMD ["node", "src/server.js"]
```

**Security hardening:**
- Multi-stage build (build tools not in final image)
- Vulnerability patches applied at build time
- Alpine-based minimal image
- npm cache cleaned

---

## Kubernetes Resources

| Resource | Name | Purpose |
|----------|------|---------|
| Deployment | `product-service` | Runs the service pods |
| Service | `product-service` | ClusterIP for internal routing |
| ConfigMap | `product-service-config` | Non-sensitive env vars |
| Secret | `product-service-secret` | App-level secrets |
| SealedSecret | `products-db-secret` | Encrypted DB credentials |
| HPA | `product-service-hpa` | Auto-scaling (2–10 pods, 60% CPU) |

### Health Probes
- **Liveness**: `GET /health` — restart pod if unresponsive
- **Readiness**: `GET /ready` — checks DB connection before accepting traffic

---

## Connection Verification

```bash
# Check pods
kubectl get pods -n main -l app=product-service

# Check service
kubectl get svc product-service -n main

# Check logs
kubectl logs -l app=product-service -n main --tail=50

# Test health
kubectl run test --rm -it --image=curlimages/curl -- curl http://product-service.main.svc.cluster.local:3002/health

# Test products endpoint
kubectl run test --rm -it --image=curlimages/curl -- curl http://product-service.main.svc.cluster.local:3002/api/products
```

---

## Secret Management
All sensitive values managed via **Bitnami SealedSecrets**:
- `products-db-secret` → `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- Mapped in deployment: `POSTGRES_USER` → `PRODUCT_DB_USER`, `POSTGRES_PASSWORD` → `PRODUCT_DB_PASSWORD`
- Encrypted YAML stored in `Vastra-helm/vastra-deployments/secrets/{env}/products-db-secret.yaml`

**No secrets are hardcoded in source code or CI workflows.**
