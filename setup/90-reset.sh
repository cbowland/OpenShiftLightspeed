#!/usr/bin/env bash
# Return the cluster to the pre-demo starting state:
#   - OLSConfig without the BYOK rag stanza (vanilla Lightspeed for Acts 1-2)
#   - inventory recreated in its broken state (also removes any fixes applied live)
source "$(dirname "$0")/lib.sh"
need oc

if [[ -n "$(oc get olsconfig cluster -o jsonpath='{.spec.ols.rag}' 2>/dev/null)" ]]; then
  oc patch olsconfig cluster --type json -p '[{"op":"remove","path":"/spec/ols/rag"}]'
  ok "BYOK rag stanza removed; Lightspeed pods will restart"
else
  ok "no BYOK rag stanza"
fi

if oc get ns "$INVENTORY_NS" >/dev/null 2>&1; then
  oc delete ns "$INVENTORY_NS" --wait=true --timeout=180s
fi
oc apply -f "$DEMO_ROOT/BowlandWidgetFactory/inventory/demo-broken/inventory-broken.yaml"
ok "inventory reset to broken state"

echo "Tip: also start a fresh Lightspeed conversation (Clear chat) so earlier answers do not leak into the next session."
echo "Waiting for Lightspeed pods..."
oc wait pods --all -n "$OLS_NAMESPACE" --for=condition=Ready --timeout=300s >/dev/null && ok "Lightspeed ready"
"$SETUP_DIR/00-preflight.sh" || true
