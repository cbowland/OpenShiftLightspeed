# Demo Runbook: OpenShift Lightspeed Complete Presentation

## Important Sequencing Note

Demos 1 and 2 must run **before** patching OLSConfig with the BYOK RAG stanza. The patch triggers a pod restart in `openshift-lightspeed` and changes Lightspeed's behavior. Use the transition slides (slides 10-15) as cover while you run `patch-olsconfig-rag.sh` and wait for pods to come back up.

**Before the presentation:** Ensure `unpatch-olsconfig-rag.sh` has been run so Demos 1 & 2 show vanilla Lightspeed behavior. Verify the `lightspeed-demo` namespace resources are healthy.

---

## Demo 1 — General Lightspeed (after slide 8)

**Goal:** Show Lightspeed answering questions grounded in Red Hat docs.

| Step | Action | What to say |
|------|--------|-------------|
| 1 | Open the OCP web console, click the Lightspeed chat icon in the masthead | "Lightspeed lives right here in the console — no separate tool" |
| 2 | Ask: **"How do I configure an OAuth identity provider with LDAP on OpenShift?"** | "A common Day 2 task. Notice the answer cites official Red Hat docs, not Stack Overflow" |
| 3 | Point out the **doc references** at the bottom of the response | "Every answer is grounded — you can click through to the source" |
| 4 | Ask: **"Create a NetworkPolicy that allows traffic from namespace frontend to backend on port 8080"** | "Now watch it generate valid YAML I could apply right now" |
| 5 | Highlight the generated YAML is ready to copy/apply | "That's the before/after from the previous slide — minutes, not 30" |

**Backup question** if time allows: *"What SCCs are available on my cluster and when should I use restricted-v2?"*

---

## Demo 2 — Live Cluster State (after slide 9)

**Goal:** Show Lightspeed inspecting the **running** cluster, not just citing docs.

**Pre-req:** The `lightspeed-demo` namespace with the PostgreSQL VM, query console, network policy, and external service should already be deployed.

| Step | Action | What to say |
|------|--------|-------------|
| 1 | Ask: **"What resources are running in the lightspeed-demo namespace?"** | "Demo 1 was doc-grounded. Now watch it look at what's actually running on this cluster" |
| 2 | Show it enumerating the VM, pods, services, routes | "It sees the KubeVirt VM, the query console deployment, the network policy — real resources" |
| 3 | Ask: **"Why can't a pod in another namespace connect to the PostgreSQL service in lightspeed-demo?"** | "This requires correlating the NetworkPolicy with cross-namespace routing — live state + docs" |
| 4 | Show the response identifying the default-deny network policy and suggesting the external service pattern | "It found the network policy AND knows how to fix it" |
| 5 | (Optional) Ask: **"Is the KubeVirt VM healthy? Are there any events I should be concerned about?"** | "It can reason about VM health too — not just pods" |

---

## Transition: Patch OLSConfig During Slides 10-15

After Demo 2, you have slides 10-15 covering the BYOK concept, architecture, build steps, and OLSConfig. **During these slides, run the patch in a separate terminal:**

```bash
# In a terminal (not shown to audience):
./patch-olsconfig-rag.sh

# Then monitor pods restarting:
oc get pods -n openshift-lightspeed -w
```

The ~5 slides of BYOK explanation give the pods time to restart with the new RAG index (~2-3 minutes).

---

## Demo 3 — Bring Your Own Knowledge (after slide 15)

**Goal:** Show Lightspeed answering questions it could **only** answer with your custom Bowland Widget Factory docs.

| Step | Action | What to say |
|------|--------|-------------|
| 1 | Ask: **"What SCCs does the Bowland Widget Factory require?"** | "This is entirely internal knowledge — no public docs exist for this. Watch what happens" |
| 2 | Show the response referencing Bowland deployment standards (non-root, restricted SCC, drop ALL capabilities) | "It pulled from our internal deployment standards — security context, non-root, drop all caps" |
| 3 | Ask: **"What labels need to be included for the Bowland Widget Factory?"** | "Every org has metadata standards. Ours require environment, business-unit, and app-name labels" |
| 4 | Show the response citing `bowland.com/environment`, `bowland.com/business-unit`, `bowland.com/app-name` labels and the `bowland.com/support-contact` annotation | "Those are our custom label standards — Lightspeed learned them from our markdown docs" |
| 5 | Ask: **"Tell me about the network policy standards for the Bowland Widget Factory"** | "Zero-trust networking, default-deny-all, explicit DNS egress — all org-specific" |
| 6 | (High impact) Contrast: *"Without BYOK, Lightspeed would have given generic Kubernetes network policy advice. With BYOK, it gives you YOUR policy."* | "No model fine-tuning happened. This is pure RAG retrieval at query time. Your data never left this cluster." |

**Bonus if time allows:** Ask *"What are the observability standards for monitoring Bowland Widget Factory deployments?"* to show it returning the specific PromQL golden signals queries.

---

## Demo 4 — MCP Server & IDE Integration (after slide 17)

**Goal:** Show the same Lightspeed + BYOK intelligence accessible from an IDE via MCP.

**Pre-req:**
- Lightspeed Route already exposed (`oc create route edge lightspeed-api ...`)
- MCP server configured in Claude Code pointing at the route (`mcp.json` with `OLS_API_URL` and `OLS_API_TOKEN` set)

| Step | Action | What to say |
|------|--------|-------------|
| 1 | Show the `mcp.json` config briefly — point out it just needs a URL and token | "Three lines of config. The MCP server bridges the Lightspeed API to any IDE that speaks MCP" |
| 2 | Open Claude Code (or Cursor/VS Code) with the MCP server active | "Same Lightspeed, same BYOK knowledge, now in the developer's workflow" |
| 3 | Ask via the IDE: **"What are the deployment resource limits required for Bowland Widget Factory production workloads?"** | "I'm in my IDE now — asking the same cluster, same custom knowledge" |
| 4 | Show the response includes the Bowland-specific resource requirements (100m CPU / 128Mi memory minimums, mandatory liveness/readiness probes) | "This came from our internal docs via RAG — the developer never left their editor" |
| 5 | Ask: **"Generate a Deployment YAML for a new Bowland Widget Factory microservice called 'inventory-api' that follows all our standards"** | "Now the developer gets YAML that already follows org policy — labels, SCCs, resource limits, probes — all baked in" |

**Closing point:** *"The pipeline is: your markdown docs → RAG embeddings → container image → OLSConfig → any interface. Console, CLI, IDE — one knowledge base, everywhere your team works."*

---

## Timing & Logistics Summary

| Demo | Slide position | Duration | OLSConfig state |
|------|---------------|----------|-----------------|
| Demo 1 | After slide 8 | ~3-4 min | **No RAG** (vanilla Lightspeed) |
| Demo 2 | After slide 9 | ~3-4 min | **No RAG** (vanilla Lightspeed) |
| *Patch OLSConfig* | *During slides 10-15* | *Background* | *Applying RAG patch* |
| Demo 3 | After slide 15 | ~4-5 min | **RAG active** (BYOK enabled) |
| Demo 4 | After slide 17 | ~3-4 min | **RAG active** (BYOK + MCP) |

## Pre-Presentation Checklist

- [ ] Run `./unpatch-olsconfig-rag.sh` to ensure no RAG stanza is active
- [ ] Verify `lightspeed-demo` namespace resources are healthy (`oc get all -n lightspeed-demo`)
- [ ] Confirm Lightspeed pods are running (`oc get pods -n openshift-lightspeed`)
- [ ] Verify the Lightspeed Route is exposed for Demo 4
- [ ] Set `OLS_API_TOKEN` in `mcp.json` / `.env` for MCP demo
- [ ] Have a second terminal ready (hidden) for running the patch during slides 10-15
- [ ] Test one quick Lightspeed question in the console to confirm it responds
