# OpenShift Lightspeed Demo

A demo environment for showcasing [OpenShift Lightspeed](https://www.redhat.com/en/technologies/cloud-computing/openshift/lightspeed) (OLS) — Red Hat's AI-powered assistant for OpenShift. This project deploys a sample application stack on OpenShift that gives Lightspeed something real to reason about: a PostgreSQL database running in a KubeVirt VM, a web-based query console, networking policies, and cross-namespace service routing.

## What's in the Demo

| Component | File | Purpose |
|---|---|---|
| PostgreSQL VM | `postgres-query-app-deployment.yaml` | A Fedora VM (via KubeVirt) running PostgreSQL with pre-loaded sample data |
| Query Console | `postgres-query-app-deployment.yaml` | A web app for running SQL queries against the database |
| External Service | `external-service.yaml` | Cross-namespace service alias so other namespaces can reach the database |
| Network Policy | `network-policy.yaml` | Restricts database access to pods within the same namespace |
| MCP Integration | `mcp.json` | Connects Claude Code to OpenShift Lightspeed via MCP |

## Prerequisites

- An OpenShift cluster with:
  - [OpenShift Virtualization](https://docs.openshift.com/container-platform/latest/virt/about_virt/about-virt.html) (KubeVirt) installed
  - [OpenShift Lightspeed](https://docs.openshift.com/lightspeed/latest/about/ols-about-openshift-lightspeed.html) deployed
- `oc` CLI authenticated to the cluster
- (Optional) [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with the [OLS MCP server](https://github.com/cbowland/ols-mcp) for the AI-to-AI integration

## Deploying the Demo

1. **Create a namespace** (or use an existing one):

   ```bash
   oc new-project lightspeed-demo
   ```

2. **Deploy the application stack:**

   ```bash
   oc apply -f postgres-query-app-deployment.yaml
   ```

   This creates the PostgreSQL VM, its service, the query console deployment, and an HTTPS route. The VM takes a few minutes to boot and initialize PostgreSQL via cloud-init.

3. **Wait for the VM to be ready:**

   ```bash
   oc get vmi -w
   ```

   Once the VM status shows `Running`, give it another minute or two for cloud-init to finish installing and configuring PostgreSQL.

4. **(Optional) Apply cross-namespace access:**

   If you want to demonstrate cross-namespace connectivity, deploy the external service in a second namespace:

   ```bash
   oc apply -f external-service.yaml -n <other-namespace>
   ```

5. **(Optional) Apply the network policy:**

   ```bash
   oc apply -f network-policy.yaml
   ```

6. **Access the query console:**

   ```bash
   oc get route query-console -o jsonpath='{.spec.host}'
   ```

   Open the URL in a browser (HTTPS) to run SQL queries against the sample database.

## Sample Data

The database (`sampledb`) is pre-loaded with three related tables:

- **employees** — 8 employees across Engineering, Marketing, Sales, and HR
- **products** — 8 products (electronics, accessories, furniture)
- **orders** — 10 orders linking employees to products with statuses (pending, shipped, completed)

## Using with OpenShift Lightspeed

With the demo deployed, you can ask Lightspeed questions like:

- "What resources are running in my namespace?"
- "Why can't my pod in another namespace connect to the PostgreSQL service?"
- "How do I troubleshoot the KubeVirt VM if PostgreSQL isn't starting?"
- "Explain the network policy that's applied to my database"
- "How do I scale the query console deployment?"

## Claude Code + Lightspeed (MCP)

The `mcp.json` file configures Claude Code to communicate with OpenShift Lightspeed via the Model Context Protocol. To use it:

1. Copy `.env` and fill in your `OLS_API_TOKEN`
2. Ensure the [OLS MCP server](https://github.com/cbowland/ols-mcp) is installed
3. Claude Code will automatically pick up the MCP configuration and can relay questions to Lightspeed

This enables a workflow where Claude Code handles code and configuration tasks while consulting Lightspeed for OpenShift-specific guidance.
