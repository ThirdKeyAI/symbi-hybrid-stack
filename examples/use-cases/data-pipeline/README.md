# Use Case: Event-Driven Data Pipeline

Process incoming data events through an agent-based ETL pipeline. The pipeline agent ingests data, transforms it, and routes output to configured destinations.

## Architecture

```
Webhook ──► Symbi Coordinator ──► pipeline_agent
                                       │
                                  ┌────┴────┐
                                  │         │
                              Ingest    Transform
                                  │         │
                                  └────┬────┘
                                       │
                                  Output Routing
                                  (GCS, webhook, DB)
```

## Setup

1. Copy the agent DSL:

```bash
cp examples/use-cases/data-pipeline/agents/pipeline_agent.dsl desktop/agents/
```

2. Restart the stack:

```bash
make desktop-down && make desktop-up
```

3. Send data events via HTTP:

```bash
curl -X POST http://localhost:8081/webhook \
  -H "Authorization: Bearer $SYMBI_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": "process_data",
    "source": "csv",
    "data": "name,value\nfoo,42\nbar,99",
    "output_format": "json",
    "destination": "gcs"
  }'
```

## Scaling

For high-volume pipelines, deploy worker agents to Cloud Run:

```bash
make cloud-deploy
```

Workers scale to 10 instances with `concurrency=1` — each data event gets a dedicated container. See `cloud/worker-agent/concurrency.yaml` for trade-offs.
