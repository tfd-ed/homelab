# n8n + Prometheus: AI Agent for Homelab Monitoring

This guide explains how to query Prometheus metrics from the n8n VM and wire them into an n8n AI Agent workflow.

## Network Context

| Service    | VM IP              | Port  |
|------------|--------------------|-------|
| Prometheus | 192.168.100.220    | 9090  |
| n8n        | 192.168.100.230    | 5678  |

Both VMs are on the same `192.168.100.0/24` LAN, so n8n can reach Prometheus directly at:

```
http://192.168.100.220:9090
```

No firewall rules or tunnels are needed for internal access.

---

## Prometheus HTTP API Cheat Sheet

Prometheus exposes a REST API at `/api/v1/`. The most useful endpoints:

| Purpose            | Endpoint                                                                 |
|--------------------|--------------------------------------------------------------------------|
| Instant query      | `GET /api/v1/query?query=<PromQL>`                                       |
| Range query        | `GET /api/v1/query_range?query=<PromQL>&start=<unix>&end=<unix>&step=<s>`|
| List all targets   | `GET /api/v1/targets`                                                    |
| List all metrics   | `GET /api/v1/label/__name__/values`                                      |
| Series metadata    | `GET /api/v1/series?match[]=<selector>`                                  |

### Example PromQL Queries

```promql
# CPU usage percentage per node
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory used (bytes)
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Disk usage percentage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Down/up status of all scrape targets
up

# n8n workflow executions (after enabling N8N_METRICS)
n8n_workflow_executions_total
```

Test any query from the n8n VM:
```bash
curl "http://192.168.100.220:9090/api/v1/query?query=up"
```

---

## Option 1 — Simple Scheduled Alerting Workflow

Use this when you want periodic health-check reports without an LLM.

**Workflow nodes:**

```
[Schedule Trigger] → [HTTP Request: query Prometheus] → [IF: threshold check] → [Send alert]
```

### HTTP Request node configuration

- **Method:** GET  
- **URL:** `http://192.168.100.220:9090/api/v1/query`  
- **Query Parameters:**
  - `query` → `up` (or any PromQL expression)

The response JSON looks like:

```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": { "instance": "192.168.100.201:9100", "job": "k8s-nodes" },
        "value": [1714600000, "1"]
      }
    ]
  }
}
```

Use a **Code** node to parse results and extract the values you care about.

---

## Option 2 — AI Agent Workflow (Recommended)

The **AI Agent** node in n8n lets an LLM call tools on demand. You expose Prometheus queries as tools, and the agent decides which queries to run based on the user's question.

### Architecture

```
[Chat / Webhook trigger]
        ↓
  [AI Agent node]
   ├── LLM: OpenAI / Ollama
   └── Tools:
        ├── query_prometheus  (HTTP Request node)
        ├── list_targets      (HTTP Request node)
        └── [optional] query_range_prometheus
        ↓
[Return response to user]
```

### Step-by-step Setup

#### 1. Create the Prometheus query tool

In the AI Agent node, add a **Tool** of type **HTTP Request**:

- **Name:** `query_prometheus`
- **Description:** `Query Prometheus for real-time infrastructure metrics. Input must be a valid PromQL expression string.`
- **Method:** GET
- **URL:** `http://192.168.100.220:9090/api/v1/query`
- **Query Parameters:**
  - `query` → `{{ $fromAI('promql_query', 'PromQL expression to execute') }}`

The `$fromAI()` function tells n8n to let the LLM fill in this parameter dynamically.

#### 2. Create the list targets tool (optional but useful)

Add a second **HTTP Request** tool:

- **Name:** `list_prometheus_targets`
- **Description:** `List all Prometheus scrape targets and their up/down status.`
- **Method:** GET
- **URL:** `http://192.168.100.220:9090/api/v1/targets`
- No dynamic parameters needed.

#### 3. Configure the LLM

In the AI Agent node, connect an LLM sub-node:

- **OpenAI** (GPT-4o / GPT-4-mini) - best tool-calling accuracy
- **Ollama** (llama3, qwen2.5) - fully local, runs on your AI VM at `192.168.100.x`

If using Ollama locally, set the base URL to your AI VM's address (e.g., `http://192.168.100.250:11434`).

#### 4. Add a system prompt

In the AI Agent node, set a system message:

```
You are a homelab infrastructure assistant. You have access to Prometheus, 
which monitors these services:
- Kubernetes nodes: 192.168.100.201, 192.168.100.202, 192.168.100.203
- Database VM (PostgreSQL, MongoDB, Redis): 192.168.100.205
- Monitoring VM: 192.168.100.220
- CI/CD VM: 192.168.100.240

When the user asks about system health, use the query_prometheus tool with 
appropriate PromQL. Always interpret the results in plain language and 
highlight any anomalies (e.g., CPU > 80%, targets that are down).
```

#### 5. Trigger options

| Trigger | Use case |
|---------|----------|
| **Chat Trigger** | Interactive Q&A via n8n chat interface |
| **Webhook Trigger** | Call from Slack, Telegram, or other bots |
| **Schedule Trigger** | Automated daily digest / anomaly detection |

---

## Option 3 — Enable n8n's Own Metrics in Prometheus

n8n can expose its own metrics (execution counts, queue depth, etc.) for Prometheus to scrape. The `n8n-setup.yml` already has the config commented out.

### Enable in n8n-setup.yml

Uncomment the metrics environment variables in the Docker Compose section:

```yaml
- N8N_METRICS=true
- N8N_METRICS_PREFIX=n8n_
```

Then re-run the playbook:

```bash
ansible-playbook ansible/playbooks/services/n8n-setup.yml -i ansible/inventory.ini
```

### Add n8n as a Prometheus scrape target

Add the following job to `monitoring_dir/prometheus/prometheus.yml` on the monitoring VM (or update the `monitoring-setup.yml` playbook):

```yaml
scrape_configs:
  # ... existing jobs ...

  - job_name: 'n8n'
    static_configs:
      - targets: ['192.168.100.230:5678']
        labels:
          instance: 'n8n-vm'
    metrics_path: /metrics
```

Reload Prometheus without restarting:

```bash
curl -X POST http://192.168.100.220:9090/-/reload
```

### Useful n8n PromQL queries

```promql
# Total workflow executions
n8n_workflow_executions_total

# Failed executions
n8n_workflow_executions_total{status="failed"}

# Active workflows
n8n_active_workflow_ids_total
```

---

## Example AI Agent Conversation

> **User:** Are all my homelab nodes up?

The agent calls `list_prometheus_targets`, reads the response, and replies:

> **Agent:** All 5 scrape targets are online. 3 Kubernetes nodes, the database VM, and the CI/CD VM are all reporting `up=1`. No issues detected.

> **User:** What's the CPU usage on the k8s master?

The agent calls `query_prometheus` with:
```
100 - (avg by(instance) (rate(node_cpu_seconds_total{instance="192.168.100.201:9100", mode="idle"}[5m])) * 100)
```

> **Agent:** The Kubernetes master node is currently using 23% CPU. That's within normal range.

---

## Troubleshooting

| Problem | Check |
|---------|-------|
| n8n can't reach Prometheus | `curl http://192.168.100.220:9090/api/v1/query?query=up` from the n8n VM |
| AI tool not calling Prometheus | Verify the tool description is clear; GPT-4o handles this more reliably than smaller models |
| PromQL returns empty result | Test the query directly in Prometheus UI at `http://192.168.100.220:9090/graph` |
| Prometheus not scraping n8n | Check `N8N_METRICS=true` is set; visit `http://192.168.100.230:5678/metrics` to confirm the endpoint exists |
