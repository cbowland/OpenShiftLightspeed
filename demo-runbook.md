# Demo Runbook v2: OpenShift Lightspeed (OpenShift 4.22, Lightspeed operator 2.0.x)

**Audience:** platform/ops and app developers. **Length:** about 40 minutes, with
`openshift-lightspeed-complete.html` (24 slides; press **N** for speaker notes).
**Story:** one fictional company, the **Bowland Widget Factory**, through four
escalating demos: docs → live troubleshooting → *your* standards → the developer's IDE.

> The previous runbook (route + `ols-mcp` IDE bridge) is kept in `demo-runbook-v1.md`.
> OpenShift 5 features (autonomous agents) are deliberately **not** demoed; they
> appear only on the roadmap slide (22).

## What's where

| Path | Purpose |
|---|---|
| `setup/` | Numbered scripts: preflight, install OLS, OLSConfig, deploy workloads, MCP server, reset |
| `BowlandWidgetFactory/inventory/demo-broken/` | Broken + non-compliant `inventory` app (Acts 2 and 4) and `fix-inventory.sh` backup |
| `BowlandWidgetFactory/bowland-widget-catalog/` | Compliant "good" app |
| `../LightspeedBYOKDemo/` (separate repo: [cbowland/LightspeedBYOKDemo](https://github.com/cbowland/LightspeedBYOKDemo), cloned next to this folder) | Standards markdown, RAG image build flow, `patch-` / `unpatch-olsconfig-rag.sh` |
| `ide/` | MCP server for Red Hat OpenShift: client config + IDE prompts |
| `LightspeedDemo/` | *Optional bonus:* Postgres-in-a-VM scenario (needs OpenShift Virtualization) |

---

## One-time environment build (the day before)

1. **Cluster:** OpenShift **4.22** with Lightspeed (Red Hat Demo Platform OLS catalog item, or your own).
   Workers need roughly **75 GiB of ephemeral storage** headroom for the Offline Knowledge Portal sidecar.
2. `cp setup/demo.env.example setup/demo.env` and edit it.
3. `oc login ...`, then run:
   ```bash
   setup/10-install-ols.sh          # skip if the catalog item already installed OLS
   export LLM_API_TOKEN=...         # only if no OLSConfig exists yet
   setup/20-apply-olsconfig.sh      # creates or normalizes OLSConfig (introspection on, no BYOK)
   setup/30-deploy-bowland.sh       # catalog (good) + inventory (broken)
   setup/40-install-mcp-server.sh   # Act 5 IDE; needs helm (brew install helm)
   ```
4. **Build the BYOK image once** (`../LightspeedBYOKDemo/README.md`, steps 1–8; clone it first with `git clone https://github.com/cbowland/LightspeedBYOKDemo.git ../LightspeedBYOKDemo` if needed). Leave it pushed but **not** patched in.
5. **Prepare the IDE repo** as described in `ide/README.md`.
6. Rehearse the full flow once, then run `setup/90-reset.sh`.

## Pre-session checklist (15 minutes before)

- [ ] `setup/90-reset.sh`: un-patches BYOK, recreates the broken inventory, then runs the preflight
- [ ] `setup/00-preflight.sh` ends with **preflight passed**
- [ ] Console open as an admin user. Lightspeed chat opens and answers "hello". Then click **Clear chat**
- [ ] Hidden terminal ready in `../LightspeedBYOKDemo/` for `./patch-olsconfig-rag.sh`
- [ ] IDE open on the demo repo with the `openshift` MCP server connected
- [ ] Browser tab on the inventory Route (it should show *Application is not available*)

---

## Act 1: Doc-grounded answers (after slide 9, about 4 minutes)

**Goal:** answers grounded in Red Hat docs, not the open internet.

| Step | Action | Say |
|---|---|---|
| 1 | Open the Lightspeed chat from the console masthead | "It lives in the console. There's no separate tool." |
| 2 | Ask **"How do I configure an LDAP identity provider on OpenShift?"** | "A common Day 2 task." |
| 3 | Point out the doc references | "Every answer cites official Red Hat docs. It runs offline in-cluster through the Knowledge Portal." |
| 4 | Ask **"Create a NetworkPolicy that allows traffic from namespace frontend to backend on port 8080"** | "Valid YAML, ready to review and apply." |

*Backup:* "What SCCs are available and when should I use restricted-v2?"

## Act 2: Live troubleshooting with a human in the loop (slides 10–12, about 8 minutes)

**Goal:** Lightspeed reads the *running* cluster, diagnoses the problem, and **asks before it changes anything**.

| Step | Action | Say |
|---|---|---|
| 1 | Show the inventory Route tab (*Application is not available*), then **Workloads → Pods**, project `bowland-inventory`. The pod shows **CreateContainerConfigError** | "The dev team says inventory is down. Let's not go tab-hopping." |
| 2 | In the chat, **Attach context** → the pod (YAML and events). Ask **"Why is this pod not starting?"** | "I'm handing it the actual pod, not pasting logs into a chatbot." |
| 3 | It should spot that `secretKeyRef` uses key **`apiToken`** but Secret `inventory-secret` has **`api-token`** | "It read the Deployment, the Secret and the events, and correlated them." |
| 4 | Ask **"Fix the deployment to use the correct secret key."** → the **approval prompt** appears → review → **Approve** | "Nothing changes until a human approves. It also only sees and does what *my* RBAC allows." |
| 5 | Pod goes Running, but the Route is still unavailable. Ask **"The inventory route in bowland-inventory still says Application is not available. Why?"** | "Second-order problem." |
| 6 | It should find `default-deny-all` with no allow-from-ingress policy and propose an `allow-from-openshift-ingress` NetworkPolicy. Approve it or apply it | "Zero-trust networking did its job. Now it tells us exactly which door to open." |

**If the live fix stalls:** `BowlandWidgetFactory/inventory/demo-broken/fix-inventory.sh` applies both fixes.
**If write approval doesn't appear** (the model chose a read-only answer): ask for the YAML patch, then apply it from the console. The point still lands.

### Transition: enable BYOK during slides 13–18

In the hidden terminal:
```bash
./patch-olsconfig-rag.sh && oc get pods -n openshift-lightspeed -w
```
The six BYOK slides cover the 2–3 minute pod restart. Click **Clear chat** before Act 3.

## Act 3: Bring your own knowledge (after slide 19, about 8 minutes)

**Goal:** Lightspeed answers with **Bowland's** internal standards. Then the payoff: a compliance review.

| Step | Action | Say |
|---|---|---|
| 1 | **"What SCCs does the Bowland Widget Factory require?"** | "No public doc exists for this. It's our internal standard." |
| 2 | **"What labels need to be included for the Bowland Widget Factory?"** | "`bowland.com/environment`, `business-unit`, `app-name`, plus the support-contact annotation." |
| 3 | **"Tell me about the network policy standards for the Bowland Widget Factory"** | "Default-deny, explicit DNS egress: our policy, not generic Kubernetes advice." |
| 4 | **The big moment:** open the `inventory` Deployment in `bowland-inventory`, **Attach context** → YAML, and ask **"Does this deployment comply with Bowland Widget Factory standards? List every gap."** | "This is what your platform team does by hand in every review." |
| 5 | Expect: replicas 1 (needs 2 or more), missing `business-unit` label, missing `support-contact` annotation, no requests/limits, no probes, no `capabilities.drop: [ALL]` / `seccompProfile` | "No fine-tuning. Plain retrieval at query time, and the docs never left the cluster." |

*Bonus:* "What are the observability standards for Bowland Widget Factory deployments?" returns PromQL golden signals.

## Act 4: Developer workflow (slides 20–21, about 6 minutes)

**4a, in the console (no extra setup):** "Generate a Deployment, Service and Route for a new Bowland microservice called `orders` in bowland-widget-factory that follows all our standards."

**4b, in the IDE** (Claude Code / VS Code / Cursor + MCP server for Red Hat OpenShift; details in `ide/README.md`):

| Step | Prompt | Say |
|---|---|---|
| 1 | Show `.mcp.json`: one URL | "One open standard, MCP. It's documented in OpenShift 4.22 and runs read-only with the `view` role." |
| 2 | "Is anything unhealthy across the bowland-* namespaces?" | "Live cluster state in my editor." |
| 3 | "Read ./standards and generate Deployment, Service, Route and NetworkPolicies for `orders` in ./deploy" | "Org standards live in the repo, cluster facts come from MCP, and the output is compliant manifests." |
| 4 | "Compare the live inventory Deployment against ./standards" | "The same gaps Lightspeed found, now caught in the developer's loop *before* review." |

> Honest framing: Lightspeed itself isn't supported inside IDEs yet. Red Hat calls that bridge a proof of concept. The supported direction today is the MCP server for Red Hat OpenShift (Technology Preview in 4.22).

## Close (slides 22–24, about 3 minutes)

- **Roadmap (22):** OpenShift 5 adds autonomous, alert-triggered investigations with approval policies. What they saw today runs on 4.22 and carries forward.
- **Get started (23)** and **Thank you (24)**.

## Optional bonus: VMs (only if OpenShift Virtualization is installed)

Deploy `LightspeedDemo/postgres-query-app-deployment.yaml` in `lightspeed-demo` and ask:
"Is the PostgreSQL VM in lightspeed-demo healthy? Any events I should worry about?" You can also attach the VM in the chat.

---

## Timing and OLSConfig state

| Segment | Slides | Minutes | OLSConfig |
|---|---|---|---|
| Intro and architecture | 1–8 | 6 | no RAG |
| Act 1 | 9 | 4 | no RAG |
| Act 2 | 10–12 | 8 | no RAG |
| BYOK concepts (*patch running*) | 13–18 | 5 | applying RAG |
| Act 3 | 19 | 8 | RAG on |
| Act 4 | 20–21 | 6 | RAG on |
| Close | 22–24 | 3 | n/a |

## Product status cheat-sheet (checked 2026-11-10)

| Capability | Status on OpenShift 4.22 |
|---|---|
| Lightspeed chat assistant | GA (operator 2.0.x, OpenShift 4.16+) |
| Cluster interaction (live state, approval-gated writes) | Technology Preview, on by default |
| Bring Your Own Knowledge | Technology Preview |
| External MCP servers in OLSConfig (`featureGates: [MCPServer]`) | Available; not used in the main flow |
| MCP server for Red Hat OpenShift (IDE) | Technology Preview (documented in OCP 4.22) |
| Lightspeed inside the IDE (`ols-mcp`) | Unsupported proof of concept: **not used** |
| Autonomous agents (`oc agentic`) | OpenShift 5 only: roadmap slide only |
