# Threat Model

## Threat Matrix

| # | Threat | Impact | Mitigation | Status |
|---|--------|--------|------------|--------|
| 1 | **Agent Impersonation** | Attacker poses as a legitimate agent to execute unauthorized actions | AgentPin ES256 credentials bind agent identity to fleet key; five discovery methods (trust bundle, local directory, chain resolver, offline, online `.well-known`); TOFU key pinning detects unexpected key changes; three-level revocation (per-credential, per-key, per-issuer) enables immediate invalidation; mutual verification for agent-to-agent trust | Mitigated |
| 2 | **Coordinator Takeover** | Attacker gains control of the coordinator to redirect all tasks | Bearer token auth on all HTTP endpoints; Cloudflare Tunnel restricts ingress to zero-trust paths; Cloud Run IAM for cloud coordinator; lease-based coordination prevents dual-active | Mitigated |
| 3 | **Secret Exfiltration** | LLM API keys or auth tokens are leaked | Desktop: `.env` not committed, `0600` key permissions; Cloud: Secret Manager with IAM-scoped access; agent secrets policy limits per-agent access; audit logging of all access | Mitigated |
| 4 | **Lateral Movement** | Compromised agent accesses other agents or services | Capability boundaries enforce strict isolation; deny lists block dangerous operations; network egress policy limits outbound connections per agent; no inter-agent communication | Mitigated |
| 5 | **Audit Tampering** | Attacker modifies or deletes audit logs to hide activity | Append-only SQLite audit table; continuous Litestream replication to GCS (immutable with versioning); JSON structured logging to Docker/Cloud Logging; 7-year retention for compliance | Mitigated |
| 6 | **Supply Chain** | Malicious container image or dependency | Images pulled from `ghcr.io/thirdkeyai/symbi` (org-controlled); Trivy scanning in CI; Dockerfile uses pinned base images; no runtime dependency installation | Mitigated |
| 7 | **State Corruption** | Database corruption from concurrent writes or replication conflicts | Litestream provides WAL-based replication (no write conflicts); lease-based coordination ensures single-writer; desktop-primary conflict resolution; manual backup capability | Mitigated |

## Attack Surfaces

### External-Facing
- **HTTP API** (`:8081/webhook`): Protected by bearer token + TLS via Cloudflare Tunnel
- **Qdrant** (`:6333`): Internal-only by default; not exposed through tunnel
- **Cloud Run endpoints**: IAM-protected, no unauthenticated access

### Internal
- **Docker socket**: Host-level access only; containers run as non-root (`symbi` user)
- **SQLite database**: Container-internal; Litestream has read access via shared volume
- **Agent DSL files**: Mounted read-only into containers

### Prompt-Level
- **Prompt injection**: All agents enforce `prompt_injection_policy: "log_and_refuse"`
- **Data disclosure**: All agents enforce `data_disclosure_policy: "deny_system_prompt"`
- **Capability boundary**: Agents cannot request capabilities outside their declared set

## Comparison: OpenClaw vs. Symbiont

| Aspect | OpenClaw | Symbiont (this stack) |
|--------|----------|----------------------|
| Agent identity | None (shared API keys) | AgentPin ES256 per-agent credentials |
| Capability control | Trust-based (honor system) | Policy-enforced deny lists |
| Audit | Application-level logging | Structured audit with 7yr retention |
| Secret isolation | Shared environment | Per-agent secret access policy |
| Network isolation | None | Per-agent egress allowlists |
| State integrity | Single-node | Litestream replication + lease coordination |
| Prompt injection | Application-dependent | Built-in `log_and_refuse` policy |
