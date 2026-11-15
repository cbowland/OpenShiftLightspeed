#!/usr/bin/env bash
# Create the OLSConfig if missing, or leave an existing one alone apart from
# making sure cluster interaction is on and no BYOK stanza is present.
#
#   export LLM_API_TOKEN=...   (only needed when creating a new OLSConfig)
#   ./20-apply-olsconfig.sh
source "$(dirname "$0")/lib.sh"
need oc

if oc get olsconfig cluster >/dev/null 2>&1; then
  ok "OLSConfig 'cluster' already exists; keeping its LLM provider settings"
  oc patch olsconfig cluster --type merge -p '{"spec":{"ols":{"introspectionEnabled":true}}}'
  ok "introspectionEnabled=true (live cluster state + approval-gated write actions)"
  if [[ -n "$(oc get olsconfig cluster -o jsonpath='{.spec.ols.rag}')" ]]; then
    oc patch olsconfig cluster --type json -p '[{"op":"remove","path":"/spec/ols/rag"}]'
    ok "removed BYOK rag stanza (Acts 1-2 start vanilla)"
  fi
  exit 0
fi

: "${LLM_API_TOKEN:?export LLM_API_TOKEN with the provider API key first}"

oc create secret generic llm-credentials -n "$OLS_NAMESPACE" \
  --from-literal=apitoken="$LLM_API_TOKEN" --dry-run=client -o yaml | oc apply -f -

extra=""
[[ "$LLM_TYPE" == "azure_openai" ]] && extra+="
        deploymentName: ${AZURE_DEPLOYMENT_NAME:?set AZURE_DEPLOYMENT_NAME}"
[[ "$LLM_TYPE" == "watsonx" ]] && extra+="
        projectID: ${WATSONX_PROJECT_ID:?set WATSONX_PROJECT_ID}"

oc apply -f - <<EOF
apiVersion: ols.openshift.io/v1alpha1
kind: OLSConfig
metadata:
  name: cluster
spec:
  llm:
    providers:
      - name: ${LLM_PROVIDER_NAME}
        type: ${LLM_TYPE}
        url: ${LLM_URL}
        credentialsSecretRef:
          name: llm-credentials
        models:
          - name: ${LLM_MODEL}${extra}
  ols:
    defaultProvider: ${LLM_PROVIDER_NAME}
    defaultModel: ${LLM_MODEL}
    introspectionEnabled: true
    toolsApprovalConfig:
      approvalType: tool_annotations
EOF
ok "OLSConfig created. Pods take a few minutes: oc get pods -n $OLS_NAMESPACE -w"
