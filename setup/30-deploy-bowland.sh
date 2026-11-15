#!/usr/bin/env bash
# Deploy the Bowland Widget Factory demo workloads:
#   - bowland-widget-catalog: the compliant "good" app (CATALOG_NS)
#   - inventory: deliberately broken + non-compliant (INVENTORY_NS) for Acts 2 and 4
source "$(dirname "$0")/lib.sh"
need oc
BWF="$DEMO_ROOT/BowlandWidgetFactory"

echo "== Catalog (compliant) -> $CATALOG_NS"
oc get ns "$CATALOG_NS" >/dev/null 2>&1 || oc create ns "$CATALOG_NS"
oc label ns "$CATALOG_NS" bowland.com/environment=prod bowland.com/business-unit=sales \
  bowland.com/app-name=bowland-widget-catalog --overwrite >/dev/null
CAT_DEPLOY="$BWF/bowland-widget-catalog/deploy"
if [[ -d "$CAT_DEPLOY" ]]; then
  oc apply -n "$CATALOG_NS" -f "$CAT_DEPLOY" -f "$CAT_DEPLOY/network-policies"
else
  # deploy/ is git-ignored in the catalog repo; fall back to the single-file manifest
  warn "$CAT_DEPLOY not found; applying $DEMO_ROOT/bowland-widget-catalog-deployment.yaml"
  oc apply -f "$DEMO_ROOT/bowland-widget-catalog-deployment.yaml"
fi

echo "== Inventory (broken) -> $INVENTORY_NS"
oc apply -f "$BWF/inventory/demo-broken/inventory-broken.yaml"

echo
ok "catalog: https://$(oc -n "$CATALOG_NS" get route bowland-widget-catalog -o jsonpath='{.spec.host}' 2>/dev/null)"
ok "inventory (expect 503 until fixed): https://$(oc -n "$INVENTORY_NS" get route inventory -o jsonpath='{.spec.host}')"
oc get pods -n "$INVENTORY_NS"
