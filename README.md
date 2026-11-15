# OpenShift Lightspeed Demo: Bowland Widget Factory

A roughly 40-minute customer demo of [OpenShift Lightspeed](https://www.redhat.com/en/technologies/cloud-computing/openshift/lightspeed)
on **OpenShift 4.22** (Lightspeed operator 2.0.x). One fictional company, the
**Bowland Widget Factory**, goes through four escalating acts:

1. **Doc-grounded answers:** Red Hat documentation, served offline in-cluster
2. **Live troubleshooting:** Lightspeed diagnoses a broken app and fixes it after human approval
3. **Bring Your Own Knowledge (BYOK):** answers and compliance reviews grounded in Bowland's internal standards
4. **Developer workflow:** the same cluster context in the IDE through the MCP server for Red Hat OpenShift

**Start here:** [`demo-runbook.md`](demo-runbook.md) is the full script, with setup, the pre-session
checklist, prompts, talking points and timing. The slides are
[`openshift-lightspeed-complete.html`](openshift-lightspeed-complete.html): open the file in a browser,
use the arrow keys to move between slides, and press **N** for speaker notes.

## What you need

- An **OpenShift 4.22 cluster** with Lightspeed (for example, the OLS item on
  [Red Hat Demo Platform](https://catalog.demo.redhat.com)). Workers need about 75 GiB of free
  ephemeral storage for the offline docs sidecar.
- An **LLM provider and API key**, if the cluster doesn't already have an `OLSConfig`.
- For Act 3 only: an **x86_64 RHEL 9 VM** with podman to build the BYOK image, plus
  registry.redhat.io credentials.
- Local tools: `oc` and `helm`.
- The companion repo [**LightspeedBYOKDemo**](https://github.com/cbowland/LightspeedBYOKDemo), cloned
  **next to** this one. It holds the Bowland standards and the BYOK build and patch scripts:

  ```text
  workspace/
  ├── OpenShiftLightspeed/   # this repo
  └── LightspeedBYOKDemo/    # git clone https://github.com/cbowland/LightspeedBYOKDemo.git
  ```

## Quick start

```bash
cp setup/demo.env.example setup/demo.env   # set LLM provider and namespaces; git-ignored
oc login ...

setup/10-install-ols.sh          # skip if Lightspeed is already installed
export LLM_API_TOKEN=...         # only if no OLSConfig exists yet
setup/20-apply-olsconfig.sh      # cluster interaction on, no BYOK
setup/30-deploy-bowland.sh       # compliant catalog app + deliberately broken inventory app
setup/40-install-mcp-server.sh   # read-only MCP server for the IDE act

setup/00-preflight.sh            # read-only check; should end with "preflight passed"
```

Then build the BYOK image once (see the LightspeedBYOKDemo README), prepare the IDE repo
([`ide/README.md`](ide/README.md)), and rehearse. Before each session, run `setup/90-reset.sh`.
It removes BYOK, re-breaks the inventory app and runs the preflight.

## Repository layout

| Path | What it is |
|---|---|
| [`demo-runbook.md`](demo-runbook.md) | The demo script (current) |
| `openshift-lightspeed-complete.html` | The slide deck (current, 24 slides) |
| [`setup/`](setup/) | Numbered setup scripts, preflight and reset. Settings go in `demo.env` |
| `BowlandWidgetFactory/bowland-widget-catalog/` | The compliant "good" app (Flask). See its [README](BowlandWidgetFactory/bowland-widget-catalog/README.md) |
| `BowlandWidgetFactory/inventory/demo-broken/` | The broken, non-compliant app for Acts 2–3, plus `fix-inventory.sh` as a backup answer key |
| [`ide/`](ide/) | MCP client config and prompts for the IDE act |
| [`LightspeedDemo/`](LightspeedDemo/) | Optional bonus: PostgreSQL in a VM (needs OpenShift Virtualization) |
| `demo-runbook-v1.md`, `openshift-lightspeed-complete-v1.html` | The previous version of the demo, kept for reference |

## Secrets and per-cluster settings

Cluster hostnames, tokens and API keys go in git-ignored files: `setup/demo.env`, any `.env`, and
`.mcp.json`. The `*.example` files are the templates. Secret values in the committed manifests are
placeholders.

## Product status (checked November 2026)

Lightspeed chat is GA. Cluster interaction, BYOK and the MCP server for Red Hat OpenShift are
Technology Preview on OpenShift 4.22. See the cheat sheet at the end of
[`demo-runbook.md`](demo-runbook.md) for details.
