# Security Model

## Trust Boundaries

The symbi-hybrid-stack has three trust boundaries:

1. **External → Ingress**: Cloudflare Tunnel (desktop) or Cloud Run IAM (cloud) handles TLS termination and authentication.
2. **Ingress → Coordinator**: Bearer token authentication (`SYMBI_AUTH_TOKEN`) validates every HTTP request.
3. **Coordinator → Agents**: The coordinator routes tasks only to agents with matching capabilities. Agents cannot communicate directly with each other.

```
External          Ingress              Coordinator          Agents
─────────► [Cloudflare/IAM] ──► [Bearer Token Auth] ──► [Capability Check]
             TLS + auth            token validation        policy enforcement
```

## Authentication Chain

1. **HTTP Bearer Token**: Every request to `/webhook` must include `Authorization: Bearer <token>`. Requests without valid tokens are rejected with 401.

2. **AgentPin Identity**: Each agent has an ES256 credential (JWT) signed by the fleet key. The credential binds the agent's `agent_id` to the organization's domain. Verification supports multiple discovery methods: trust bundles for air-gapped environments, local discovery directories for CI/CD, offline mode for fully disconnected operation, chain resolvers for layered fallbacks, and online `.well-known/agent-identity.json` for public-facing agents. TOFU key pinning (`--pin-store`) records public keys on first contact and rejects unexpected key changes. Three-level revocation (per-credential, per-key, per-issuer) enables immediate invalidation via offline revocation documents or online endpoints.

3. **Cloud Run IAM**: Cloud services use Google IAM service accounts. Only the coordinator service account can invoke worker services.

## Encryption

| Layer | Mechanism |
|-------|-----------|
| In transit | TLS 1.3 (Cloudflare Tunnel / Cloud Run) |
| At rest (desktop) | Volume-level encryption (host OS) |
| At rest (cloud) | Google-managed encryption (AES-256) |
| State replication | TLS to GCS, server-side encryption |
| Secrets | Docker secrets (desktop), Secret Manager (cloud) |

## Secrets Management

### Desktop
- `.env` file with restrictive permissions (not committed to git)
- AgentPin private keys stored in `secrets/` with `0600` permissions
- Docker Compose reads secrets from environment variables

### Cloud
- Google Secret Manager for `SYMBI_AUTH_TOKEN` and LLM API keys
- Cloud Run mounts secrets as environment variables
- Service account IAM controls which services can access which secrets

## Agent Sandboxing

Each agent runs with:
- **Capability boundary**: Can only perform actions listed in `capabilities`
- **Deny list**: Explicitly blocked from dangerous operations (`code_execution`, `system_access`)
- **Prompt injection policy**: `log_and_refuse` — logs the attempt and returns a refusal
- **Data disclosure policy**: `deny_system_prompt` — never reveals internal prompts
- **Network egress**: Controlled by `desktop/policies/network.policy.dsl`
- **Secret access**: Controlled by `desktop/policies/secrets.policy.dsl`

## Compliance

- **Audit logging**: All agent invocations are logged with input/output capture (configurable per agent)
- **Retention**: 7 years for SOX/HIPAA compliance events, 1 year for general events
- **Immutable audit trail**: Audit logs are append-only in the SQLite database, replicated to GCS
- **Redaction**: Sensitive fields (API keys, tokens) are automatically redacted from logs
