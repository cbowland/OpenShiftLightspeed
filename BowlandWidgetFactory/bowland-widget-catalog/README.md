# Bowland Widget Catalog

A lightweight Flask web application that serves a browsable product catalog for
the fictional **Bowland Widget Factory**. Designed as a demo workload whose
OpenShift deployment artifacts exercise every Bowland platform standard.

## Features

| Endpoint | Method | Purpose |
|---|---|---|
| `/` | GET | Browsable HTML catalog UI |
| `/api/widgets` | GET | List all widgets (JSON) |
| `/api/widgets/<id>` | GET | Get a single widget (JSON) |
| `/api/widgets` | POST | Add a widget (requires `X-API-Key` header) |
| `/healthz` | GET | Liveness probe |
| `/readyz` | GET | Readiness probe |
| `/metrics` | GET | Prometheus metrics |

## Run Locally

```bash
cd bowland-widget-catalog
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit .env with your values
python3 app.py
# Open http://localhost:8080
```

The app automatically loads variables from a `.env` file when present.
You can also pass variables inline: `ADMIN_API_KEY=my-secret-key python3 app.py`

## Run Locally with a Container

```bash
podman run -p 8080:8080 -e ADMIN_API_KEY=my-secret-key bowland-widget-catalog:latest
```

## Build the Container Image (Mac → OpenShift)

Building on Apple Silicon for deployment to x86_64 OpenShift clusters:

```bash
# Build for linux/amd64 so the image runs on OpenShift
podman build --platform linux/amd64 -t bowland-widget-catalog:latest .

# Tag for your quay.io registry
podman tag bowland-widget-catalog:latest quay.io/<YOUR_QUAY_USER>/bowland-widget-catalog:latest

# Log in to quay.io (one-time)
podman login quay.io

# Push
podman push quay.io/<YOUR_QUAY_USER>/bowland-widget-catalog:latest
```

> Make the repository **public** in quay.io so OpenShift can pull it without an
> image pull secret, or create a `kubernetes.io/dockerconfigjson` Secret if you
> prefer to keep it private.

## Configuration (Environment Variables)

These are typically injected via a ConfigMap and a Secret in OpenShift.

| Variable | Default | Source | Description |
|---|---|---|---|
| `CATALOG_TITLE` | Bowland Widget Catalog | ConfigMap | Page title |
| `ITEMS_PER_PAGE` | 12 | ConfigMap | Widgets shown per page |
| `ENABLE_ADMIN` | true | ConfigMap | Enable/disable POST endpoint |
| `ADMIN_API_KEY` | *(random)* | Secret | API key for admin operations |

## Testing the Admin API

```bash
curl -X POST http://localhost:8080/api/widgets \
  -H "Content-Type: application/json" \
  -H "X-API-Key: my-secret-key" \
  -d '{"name":"New Widget","category":"Gears","price":9.99,"description":"A brand new widget."}'
```
