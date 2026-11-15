#!/usr/bin/env bash
# Install the MCP server for Red Hat OpenShift (Technology Preview in OCP 4.22),
# read-only ("view" ClusterRole). It is used by the IDE act (Claude Code / VS Code / Cursor).
# Docs: OCP 4.22 > AI applications > MCP server > Install the MCP server Helm chart
source "$(dirname "$0")/lib.sh"
need oc; need helm

host="${MCP_HOST:-mcp-server.$(apps_domain)}"
helm repo add openshift-helm-charts https://charts.openshift.io/ >/dev/null 2>&1 || true
helm repo update openshift-helm-charts >/dev/null

helm upgrade -i -n "$MCP_NS" --create-namespace openshift-mcp-server \
  openshift-helm-charts/redhat-openshift-mcp-server \
  --set config.toolsets="$MCP_TOOLSETS" \
  --set ingress.host="$host" \
  --set openshift=true \
  --set-json 'rbac.extraClusterRoleBindings=[{"name":"use-view-role","roleRef":{"name":"view","external":true}}]'

oc -n "$MCP_NS" rollout status deploy --timeout=180s || true
echo
ok "MCP endpoint: https://$host/mcp"
echo "   Next: cp $DEMO_ROOT/ide/mcp.json.example <your-repo>/.mcp.json and set the URL (see ide/README.md)"
