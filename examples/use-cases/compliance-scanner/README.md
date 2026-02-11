# Use Case: Scheduled Compliance Scanner

Run automated HIPAA and SOX compliance checks on a schedule. The compliance agent scans configurations, access logs, and data handling practices, then generates reports.

## Architecture

```
Cron/Scheduler ──► Symbi HTTP API ──► compliance_agent
                                           │
                                      ┌────┴────┐
                                      │         │
                                   HIPAA     SOX
                                   checks   checks
                                      │         │
                                      └────┬────┘
                                           │
                                      Audit Report
```

## Setup

1. Copy the agent DSL:

```bash
cp examples/use-cases/compliance-scanner/agents/compliance_agent.dsl desktop/agents/
```

2. Restart the stack:

```bash
make desktop-down && make desktop-up
```

3. Set up a cron job to trigger scans:

```bash
# Run compliance check daily at 6 AM
0 6 * * * curl -sf -H "Authorization: Bearer $SYMBI_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  http://localhost:8081/webhook \
  -d '{"task": "compliance_scan", "frameworks": ["hipaa", "sox"]}'
```

## Reports

Compliance reports are stored in the audit log with:
- `data_classification: "compliance_sensitive"`
- `retention: "7_years"` (2555 days)
- Full input/output capture for regulatory review
