#!/usr/bin/env bash
# Read-only checks: run before every customer session. Changes nothing.
source "$(dirname "$0")/lib.sh"
need oc
rc=0

echo "== Cluster"
oc whoami >/dev/null 2>&1 && ok "logged in as $(oc whoami) @ $(oc whoami --show-server)" || { fail "not logged in (oc login ...)"; exit 1; }
ver=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
if [[ "$ver" == "$EXPECTED_OCP_MINOR".* ]]; then ok "OpenShift $ver"
elif [[ "$ver" == 5.* ]]; then fail "OpenShift $ver: this demo targets 4.x (customer is not on 5 until 2027)"; rc=1
else warn "OpenShift $ver (expected $EXPECTED_OCP_MINOR.x)"; fi

echo "== OpenShift Lightspeed"
csv=$(oc get csv -n "$OLS_NAMESPACE" -o jsonpath='{range .items[?(@.spec.displayName)]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | grep lightspeed || true)
[[ -n "$csv" ]] && ok "operator: $csv" || { fail "lightspeed-operator not installed (run 10-install-ols.sh)"; rc=1; }
if oc get olsconfig cluster >/dev/null 2>&1; then
  ok "OLSConfig 'cluster' present"
  printf '     provider/model: %s / %s\n' \
    "$(oc get olsconfig cluster -o jsonpath='{.spec.ols.defaultProvider}')" \
    "$(oc get olsconfig cluster -o jsonpath='{.spec.ols.defaultModel}')"
  intro=$(oc get olsconfig cluster -o jsonpath='{.spec.ols.introspectionEnabled}')
  [[ "$intro" == "false" ]] && { fail "introspectionEnabled=false: Act 2 (live cluster) will not work"; rc=1; } || ok "cluster interaction enabled (introspectionEnabled=${intro:-default true})"
  rag=$(oc get olsconfig cluster -o jsonpath='{.spec.ols.rag}')
  [[ -z "$rag" ]] && ok "no BYOK RAG stanza (correct starting state for Acts 1-2)" || warn "BYOK RAG already patched: run ../LightspeedBYOKDemo/unpatch-olsconfig-rag.sh (sibling repo) or setup/90-reset.sh before the session"
  [[ "$(oc get olsconfig cluster -o jsonpath='{.spec.ols.byokRAGOnly}')" == "true" ]] && { fail "byokRAGOnly=true disables Red Hat docs (Act 1)"; rc=1; }
else
  fail "no OLSConfig 'cluster' (run 20-apply-olsconfig.sh)"; rc=1
fi
echo "   pods in $OLS_NAMESPACE:"
oc get pods -n "$OLS_NAMESPACE" -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase' 2>/dev/null | sed 's/^/     /'
notready=$(oc get pods -n "$OLS_NAMESPACE" --no-headers 2>/dev/null | awk '$3!="Running" && $3!="Completed"' | wc -l | tr -d ' ')
[[ "$notready" == "0" ]] && ok "all Lightspeed pods running" || { warn "$notready Lightspeed pod(s) not Running"; rc=1; }

echo "== Node ephemeral storage (Offline Knowledge Portal sidecar recommends ~75Gi)"
oc get nodes -l node-role.kubernetes.io/worker -o custom-columns='NODE:.metadata.name,EPHEMERAL:.status.allocatable.ephemeral-storage' | sed 's/^/     /'

echo "== Demo workloads"
for ns in "$CATALOG_NS" "$INVENTORY_NS"; do
  oc get ns "$ns" >/dev/null 2>&1 && ok "namespace $ns exists" || warn "namespace $ns missing (run 30-deploy-bowland.sh)"
done
if oc get deploy inventory -n "$INVENTORY_NS" >/dev/null 2>&1; then
  key=$(oc get deploy inventory -n "$INVENTORY_NS" -o jsonpath='{.spec.template.spec.containers[0].env[1].valueFrom.secretKeyRef.key}')
  [[ "$key" == "apiToken" ]] && ok "inventory is in its broken starting state" || warn "inventory already fixed: run 90-reset.sh"
fi

echo "== MCP server for Red Hat OpenShift (Act 4, optional)"
oc get route -n "$MCP_NS" -o jsonpath='{range .items[*]}{"     https://"}{.spec.host}{"/mcp\n"}{end}' 2>/dev/null || true
if [[ -n "$(oc get deploy -n "$MCP_NS" -o name 2>/dev/null)" ]]; then ok "MCP server deployed in $MCP_NS"
else warn "MCP server not installed in $MCP_NS (40-install-mcp-server.sh). The openshift-mcp-server pod in $OLS_NAMESPACE is Lightspeed's built-in one, not the IDE endpoint"; fi

echo
[[ $rc == 0 ]] && ok "preflight passed" || fail "preflight found problems (see above)"
exit $rc
