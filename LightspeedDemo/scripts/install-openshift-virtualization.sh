#!/usr/bin/env bash
#
# Installs OpenShift Virtualization (KubeVirt + HyperConverged Operator stack) on
# an OpenShift cluster using the official OLM workflow: Namespace, OperatorGroup,
# Subscription to kubevirt-hyperconverged, then HyperConverged CR. The operator
# brings in Containerized Data Importer (CDI) and other bundled components.
#
# Docs: https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/virtualization/installing
#
# Prerequisites (cluster / policy — not installed by this script):
#   - OpenShift 4.x workers on a supported platform with hardware virtualization
#   - cluster-admin via oc
#   - redhat-operators catalog available in openshift-marketplace
#   - Default or virtualization-tuned StorageClass for VM disks (configure separately)
#
# Usage:
#   ./install-openshift-virtualization.sh
#   CNV_CHANNEL=stable CNV_INSTALL_PLAN_APPROVAL=Automatic ./install-openshift-virtualization.sh
#
# Optional:
#   CNV_STARTING_CSV=kubevirt-hyperconverged-operator.v4.16.32  # pin CSV; omit for latest in channel
#   SKIP_HYPERCONVERGED=1                                      # subscribe only, skip HyperConverged CR
#   VIRTCTL_INSTALL_DIR=$HOME/bin ./install-openshift-virtualization.sh   # also fetch virtctl
#

set -euo pipefail

readonly CNV_NS="openshift-cnv"
readonly OG_NAME="kubevirt-hyperconverged-group"
readonly SUB_NAME="hco-operatorhub"
readonly HCO_NAME="kubevirt-hyperconverged"

CNV_CHANNEL="${CNV_CHANNEL:-stable}"
CNV_INSTALL_PLAN_APPROVAL="${CNV_INSTALL_PLAN_APPROVAL:-Automatic}"
SKIP_HYPERCONVERGED="${SKIP_HYPERCONVERGED:-0}"
VIRTCTL_INSTALL_DIR="${VIRTCTL_INSTALL_DIR:-}"

CSV_WAIT_SECONDS="${CSV_WAIT_SECONDS:-2400}"
HCO_WAIT_SECONDS="${HCO_WAIT_SECONDS:-3600}"

usage() {
  sed -n '1,35p' "$0" | sed -n '/^#/p' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

need_cmd oc

if ! oc whoami &>/dev/null; then
  die "Not logged in. Run: oc login <api-url>"
fi

if ! oc auth can-i create namespaces --all-namespaces &>/dev/null; then
  die "Current user cannot create namespaces cluster-wide; cluster-admin is required."
fi

if ! oc get packagemanifest kubevirt-hyperconverged -n openshift-marketplace &>/dev/null; then
  die "PackageManifest kubevirt-hyperconverged not found. Ensure redhat-operators CatalogSource is healthy."
fi

build_subscription_yaml() {
  local starting="${CNV_STARTING_CSV:-}"
  if [[ -n "${starting}" ]]; then
    printf '%s\n' "  startingCSV: ${starting}"
  fi
}

log "Applying Namespace, OperatorGroup, and Subscription in ${CNV_NS}..."
sub_extra="$(build_subscription_yaml)"
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CNV_NS}
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${OG_NAME}
  namespace: ${CNV_NS}
spec:
  targetNamespaces:
    - ${CNV_NS}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${SUB_NAME}
  namespace: ${CNV_NS}
spec:
  channel: "${CNV_CHANNEL}"
  installPlanApproval: ${CNV_INSTALL_PLAN_APPROVAL}
  name: kubevirt-hyperconverged
  source: redhat-operators
  sourceNamespace: openshift-marketplace
${sub_extra}
EOF

if [[ "${CNV_INSTALL_PLAN_APPROVAL}" == "Manual" ]]; then
  log "Subscription uses Manual installPlanApproval; approve the InstallPlan so the operator can install:"
  log "  oc get installplan -n ${CNV_NS}"
  log "  oc patch installplan <name> -n ${CNV_NS} --type merge -p '{\"spec\":{\"approved\":true}}'"
fi

wait_for_csv_succeeded() {
  local deadline=$((SECONDS + CSV_WAIT_SECONDS))
  log "Waiting for OpenShift Virtualization ClusterServiceVersion (up to ${CSV_WAIT_SECONDS}s)..."
  while (( SECONDS < deadline )); do
    local phase
    phase="$(
      oc get csv -n "${CNV_NS}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null \
        | awk -F'\t' '$1 ~ /^kubevirt-hyperconverged-operator\./ {print $2; exit}'
    )"
    if [[ "${phase}" == "Succeeded" ]]; then
      log "ClusterServiceVersion phase: Succeeded"
      oc get csv -n "${CNV_NS}" | grep kubevirt-hyperconverged-operator || true
      return 0
    fi
    if [[ -n "${phase}" && "${phase}" != "Installing" && "${phase}" != "Pending" && "${phase}" != "Replacing" ]]; then
      log "CSV phase: ${phase} (still waiting...)"
    fi
    sleep 15
  done
  log "Current CSV objects in ${CNV_NS}:"
  oc get csv -n "${CNV_NS}" || true
  die "Timed out waiting for kubevirt-hyperconverged CSV to reach Succeeded."
}

wait_for_csv_succeeded

if [[ "${SKIP_HYPERCONVERGED}" == "1" ]]; then
  log "SKIP_HYPERCONVERGED=1 set; not creating HyperConverged. Create it when ready:"
  log "  oc apply -f - <<'YAML'"
  log "apiVersion: hco.kubevirt.io/v1beta1"
  log "kind: HyperConverged"
  log "metadata:"
  log "  name: ${HCO_NAME}"
  log "  namespace: ${CNV_NS}"
  log "spec: {}"
  log "YAML"
  exit 0
fi

log "Applying HyperConverged CR (${HCO_NAME})..."
oc apply -f - <<EOF
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: ${HCO_NAME}
  namespace: ${CNV_NS}
spec: {}
EOF

log "Waiting for HyperConverged to become Available (up to ${HCO_WAIT_SECONDS}s)..."
if oc wait "hco/${HCO_NAME}" -n "${CNV_NS}" \
  --for=condition=Available \
  --timeout="${HCO_WAIT_SECONDS}s" 2>/dev/null; then
  log "HyperConverged condition Available=True"
else
  log "oc wait on Available timed out or is unsupported; polling status..."
  avail=""
  deadline=$((SECONDS + HCO_WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    avail="$(
      oc get "hco/${HCO_NAME}" -n "${CNV_NS}" -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\n"}{end}' 2>/dev/null \
        | awk -F'\t' '$1=="Available"{print $2; exit}'
    )"
    if [[ "${avail}" == "True" ]]; then
      log "HyperConverged reports Available=True"
      break
    fi
    sleep 20
  done
  if [[ "${avail:-}" != "True" ]]; then
    oc get "hco/${HCO_NAME}" -n "${CNV_NS}" -o yaml || true
    die "HyperConverged did not become Available in time."
  fi
fi

log "Enabling KVM software emulation (required for non-baremetal / nested-virt clusters)..."
oc annotate --overwrite "hco/${HCO_NAME}" -n "${CNV_NS}" \
  'kubevirt.kubevirt.io/jsonpatch=[{"op": "add", "path": "/spec/configuration/developerConfiguration/useEmulation", "value": true}]'

log "Core pods in ${CNV_NS}:"
oc get pods -n "${CNV_NS}" --no-headers 2>/dev/null | head -20 || true

virtctl_hint() {
  local ver
  ver="$(oc get csv -n "${CNV_NS}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -E '^kubevirt-hyperconverged-operator\.' | head -1)"
  ver="${ver##kubevirt-hyperconverged-operator.v}"
  log ""
  log "virtctl (optional CLI): install a build matching your cluster, e.g. from the console"
  log "Downloads page or KubeVirt releases. HyperConverged operator CSV version suffix: ${ver:-unknown}"
}

if [[ -n "${VIRTCTL_INSTALL_DIR}" ]]; then
  need_cmd curl
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  kv_ver=""
  kv_wait=$((SECONDS + 600))
  while (( SECONDS < kv_wait )); do
    kv_ver="$(oc get kubevirt.kubevirt.io/kubevirt -n "${CNV_NS}" -o jsonpath='{.status.observedKubeVirtVersion}' 2>/dev/null || true)"
    [[ -n "${kv_ver}" ]] && break
    sleep 15
  done
  if [[ -z "${kv_ver}" ]]; then
    log "Could not read observedKubeVirtVersion after 10m; skipping virtctl download. Re-run with VIRTCTL_INSTALL_DIR after KubeVirt is up."
    virtctl_hint
  else
    mkdir -p "${VIRTCTL_INSTALL_DIR}"
    tmp="$(mktemp -d)"
    cleanup() { rm -rf "${tmp}"; }
    trap cleanup EXIT
    url="https://github.com/kubevirt/kubevirt/releases/download/v${kv_ver}/virtctl-v${kv_ver}-${os}-${arch}"
    log "Downloading virtctl v${kv_ver} for ${os}-${arch}..."
    curl -fsSL -o "${tmp}/virtctl" "${url}"
    chmod +x "${tmp}/virtctl"
    mv "${tmp}/virtctl" "${VIRTCTL_INSTALL_DIR}/virtctl"
    trap - EXIT
    rm -rf "${tmp}"
    log "Installed: ${VIRTCTL_INSTALL_DIR}/virtctl"
  fi
else
  virtctl_hint
fi

log ""
log "OpenShift Virtualization install finished."
log "Verify: oc get vmi -A   (after you create a VM)"
