# IDE act: MCP server for Red Hat OpenShift

Act 4 of the demo shows a developer working in their editor. The assistant reaches
the cluster through the **MCP server for Red Hat OpenShift**. That server is
documented in OCP 4.22 (AI applications > MCP server) as a **Technology Preview**,
and it is installed with Helm by `../setup/40-install-mcp-server.sh`.

> Why not "Lightspeed in the IDE"? Red Hat has no supported way to put Lightspeed
> itself in an IDE yet. The `ols-mcp` bridge is an unsupported proof of concept, so
> this demo no longer uses it.

## What the audience sees

- The IDE assistant (Claude Code, VS Code with Copilot agent mode, or Cursor)
  lists pods and events and reads logs, all through MCP.
- The server runs **read-only**: it is bound to the `view` ClusterRole, so it can
  inspect the cluster but cannot change it. Mention this for ops and security
  audiences.
- The developer's repo contains the Bowland standards
  (`BowlandWidgetFactoryOCPStandards/` in the separate
  [LightspeedBYOKDemo](https://github.com/cbowland/LightspeedBYOKDemo) repo, cloned next to this folder). The assistant uses
  them together with live cluster state to write compliant manifests.

## Setup

1. Run `../setup/40-install-mcp-server.sh`. It prints the endpoint,
   `https://mcp-server.<apps-domain>/mcp`.
2. Create a scratch "developer repo" and copy in the config and standards:
   ```bash
   mkdir -p ~/demo/bowland-orders && cd ~/demo/bowland-orders
   cp <this-dir>/mcp.json.example .mcp.json          # Claude Code
   # VS Code: put the same server under "servers" in .vscode/mcp.json
   # Cursor:  ~/.cursor/mcp.json or .cursor/mcp.json
   sed -i '' "s#https://mcp-server.apps.CLUSTER_DOMAIN/mcp#https://<your-host>/mcp#" .mcp.json
   cp -r <demo-root>/../LightspeedBYOKDemo/BowlandWidgetFactoryOCPStandards ./standards
   ```
3. Accept the cluster CA certificate if the client asks, and approve the
   `openshift` MCP server when it first starts.
4. Smoke test: ask "list the pods in bowland-inventory". It should answer from
   the live cluster.

## Prompts for the demo

1. *"Using the openshift MCP server, what's running in the bowland-widget-factory
   namespace and is anything unhealthy across the bowland-* namespaces?"*
2. *"Read ./standards and generate a Deployment, Service, Route and NetworkPolicies
   for a new microservice called `orders` in bowland-widget-factory that follows
   every Bowland standard. Save them under ./deploy."*
3. *"Compare the live inventory Deployment in bowland-inventory against
   ./standards and list every violation."* The IDE should report the same gaps
   Lightspeed found in Act 3.

Do not commit a `.mcp.json` that contains a real cluster hostname to a public repo.
