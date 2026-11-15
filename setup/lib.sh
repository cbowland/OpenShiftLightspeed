# Shared helpers, sourced by the numbered setup scripts.
set -euo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "$SETUP_DIR/.." && pwd)"
if [[ -f "$SETUP_DIR/demo.env" ]]; then
  # shellcheck disable=SC1091
  source "$SETUP_DIR/demo.env"
else
  echo "WARN: $SETUP_DIR/demo.env not found; using demo.env.example defaults" >&2
  # shellcheck disable=SC1091
  source "$SETUP_DIR/demo.env.example"
fi
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$*"; }
need() { command -v "$1" >/dev/null || { fail "missing CLI: $1"; exit 1; }; }
apps_domain() { oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'; }
