#!/usr/bin/env bash
# Backup "answer key" for demo Act 2. It applies the same fixes Lightspeed should
# propose, in case the live fix runs long or you are short on time.
#   1. Point the secretKeyRef at the real key (api-token)
#   2. Add the missing allow-from-openshift-ingress NetworkPolicy
set -euo pipefail
NS="${INVENTORY_NS:-bowland-inventory}"

oc -n "$NS" patch deployment inventory --type json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/1/valueFrom/secretKeyRef/key","value":"api-token"}
]'

oc -n "$NS" apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-openshift-ingress
  labels:
    bowland.com/environment: dev
    bowland.com/business-unit: retail
    bowland.com/app-name: inventory
spec:
  podSelector:
    matchLabels:
      bowland.com/app-name: inventory
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              network.openshift.io/policy-group: ingress
EOF

oc -n "$NS" rollout status deployment/inventory --timeout=120s
echo "Route: https://$(oc -n "$NS" get route inventory -o jsonpath='{.spec.host}')"
