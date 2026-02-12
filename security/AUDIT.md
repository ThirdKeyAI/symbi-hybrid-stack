# Audit Guide

## Reading Audit Logs

Audit logs are written as JSON to stdout (Docker logs) and to `/var/lib/symbi/audit.log` inside the container.

### View logs via Docker

```bash
# All logs
docker logs symbi-coordinator

# Follow in real-time
docker logs -f symbi-coordinator

# Filter for specific events
docker logs symbi-coordinator 2>&1 | jq 'select(.event == "auth_failure")'
```

### Log format

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "event": "agent_invocation",
  "agent_id": "coordinator",
  "request_id": "req_abc123",
  "input": { "task": "route_request", "target": "data_processor" },
  "output": { "status": "routed", "task_id": "task_xyz" },
  "duration_ms": 1250,
  "auth": { "method": "bearer_token", "valid": true }
}
```

### Event types

| Event | Description |
|-------|-------------|
| `agent_invocation` | Agent was called with a task |
| `task_assignment` | Coordinator assigned a task to an agent |
| `task_completion` | Agent completed a task |
| `auth_success` | Successful authentication |
| `auth_failure` | Failed authentication attempt |
| `policy_violation` | Agent tried to exceed its capabilities |
| `prompt_injection_attempt` | Detected prompt injection in input |
| `capability_denied` | Agent requested a denied capability |
| `health_check` | Health check result |
| `failover_event` | Coordinator lease changed |

## Verifying Credential Chains

Use AgentPin to verify the full credential chain. Multiple discovery methods are available depending on your environment:

```bash
# Trust bundle verification (air-gapped / fleet-internal)
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --credential secrets/coordinator.jwt

# Trust bundle + TOFU pin store
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --credential secrets/coordinator.jwt \
    --pin-store secrets/pin-store.json

# Local discovery directory (CI/CD, dev, testing)
agentpin verify \
    --discovery-dir ./secrets \
    --credential secrets/coordinator.jwt

# Fully offline verification
agentpin verify \
    --offline \
    --discovery secrets/discovery.json \
    --credential secrets/coordinator.jwt

# Online .well-known discovery (public-facing)
agentpin verify \
    --credential secrets/coordinator.jwt

# Chain resolver: trust bundle + local directory fallback
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --discovery-dir ./secrets \
    --credential secrets/coordinator.jwt

# Verify with offline revocation check
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --credential secrets/coordinator.jwt \
    --revocation secrets/revocations.json

# Verify with audience restriction
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --credential secrets/coordinator.jwt \
    --audience yourdomain.com
```

### What to check

1. **Key validity**: The fleet key has not been rotated since credentials were issued
2. **Agent binding**: The credential's `agent_id` matches the expected agent
3. **Domain binding**: The credential's issuer matches your `AGENTPIN_DOMAIN`
4. **Algorithm**: Only ES256 (ECDSA P-256) — any other algorithm indicates tampering
5. **Revocation status**: Credential has not been revoked (check revocations.json or revocation endpoint)
6. **Key pinning**: Public key matches the pinned key in pin-store.json (TOFU)
7. **Audience**: Credential audience matches the expected domain (`--audience`)

## Checking Replication Integrity

### Litestream status

```bash
# Check Litestream container is running
docker logs symbi-litestream

# Check replication lag (look for "replicated" messages)
docker logs symbi-litestream 2>&1 | tail -20
```

### GCS verification

```bash
# List replicated snapshots
gsutil ls -l "gs://${GCS_STATE_BUCKET}/state/"

# Compare local and remote database sizes
docker exec symbi-coordinator ls -la /var/lib/symbi/symbi.db
gsutil stat "gs://${GCS_STATE_BUCKET}/state/symbi.db"
```

### Manual integrity check

```bash
# Snapshot current state
bash desktop/scripts/backup-state.sh

# Check SQLite integrity
sqlite3 state/backups/symbi_*.db "PRAGMA integrity_check;"
```
