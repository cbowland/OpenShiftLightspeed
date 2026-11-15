#!/usr/bin/env bash
# Install the OpenShift Lightspeed operator (lightspeed-operator, OwnNamespace mode).
# Safe to re-run. Skip it if the Demo Platform item already installed OLS.
source "$(dirname "$0")/lib.sh"
need oc

oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${OLS_NAMESPACE}
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${OLS_NAMESPACE}
  namespace: ${OLS_NAMESPACE}
spec:
  targetNamespaces:
    - ${OLS_NAMESPACE}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: lightspeed-operator
  namespace: ${OLS_NAMESPACE}
spec:
  channel: ${OLS_CHANNEL}
  name: lightspeed-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

echo "Waiting for the lightspeed-operator CSV to succeed..."
for _ in $(seq 1 60); do
  phase=$(oc get csv -n "$OLS_NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.status.phase}{"\n"}{end}' 2>/dev/null | grep lightspeed || true)
  [[ "$phase" == *"=Succeeded"* ]] && { ok "$phase"; exit 0; }
  sleep 10
done
fail "operator did not become ready in 10 minutes: oc get csv,installplan -n $OLS_NAMESPACE"
exit 1
