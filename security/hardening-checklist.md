# Production Hardening Checklist

Use this checklist before going to production. Each item reduces attack surface or improves observability.

## Authentication & Secrets

- [ ] Generate a strong `SYMBI_AUTH_TOKEN` (at least 32 random bytes)
- [ ] Rotate `SYMBI_AUTH_TOKEN` on a regular schedule (quarterly recommended)
- [ ] Store LLM API keys in Secret Manager (cloud) or encrypted vault (desktop)
- [ ] Verify private key permissions are `0600` (`ls -la secrets/`)
- [ ] Remove any test/demo tokens from `.env`
- [ ] Confirm `.env` and `secrets/` are in `.gitignore`

## Network

- [ ] Enable Cloudflare Tunnel for desktop ingress (no open ports)
- [ ] Disable Qdrant external port binding if not needed externally
- [ ] Review `desktop/policies/network.policy.dsl` — remove unused egress rules
- [ ] Enable Cloud Armor WAF on Cloud Run services (cloud)
- [ ] Configure VPC connector for Cloud Run (private networking)

## Identity

- [ ] Run `make keygen` to generate fresh AgentPin credentials
- [ ] Set `AGENTPIN_DOMAIN` to your production domain
- [ ] Initialize TOFU pin store: verify a credential with `--pin-store secrets/pin-store.json`
- [ ] Confirm pin store permissions are `0600` (`ls -la secrets/pin-store.json`)
- [ ] Create revocation document (`secrets/revocations.json`) and publish to revocation endpoint
- [ ] Choose discovery method for your environment:
  - Production (public): publish `.well-known/agent-identity.json` on your domain
  - Air-gapped / enterprise: distribute trust bundles out-of-band
  - CI/CD / dev: use `--discovery-dir` with local discovery files
  - Fully disconnected: use `--offline --discovery <file>`
- [ ] Verify credentials with correct method: `agentpin verify --trust-bundle secrets/trust-bundle.json --credential secrets/<agent>.jwt`
- [ ] Monitor pin store for unexpected key changes (alerts on pin mismatch)
- [ ] Back up pin store — loss requires re-pinning all keys

## Monitoring & Alerting

- [ ] Configure Cloud Monitoring alerts for Cloud Run error rates
- [ ] Set up Slack/PagerDuty notifications for `auth_failure` events
- [ ] Monitor Litestream replication lag (alert if >10s)
- [ ] Set up uptime checks for the HTTP endpoint
- [ ] Review audit logs weekly for anomalies

## IAM (Cloud)

- [ ] Review service account permissions — principle of least privilege
- [ ] Remove unused IAM bindings
- [ ] Enable audit logging on Secret Manager access
- [ ] Restrict who can deploy to Cloud Run (IAM roles)

## Container Security

- [ ] Run Trivy scan on container images: `trivy image ghcr.io/thirdkeyai/symbi:latest`
- [ ] Verify containers run as non-root (`USER symbi` in Dockerfile)
- [ ] Pin image tags in production (avoid `:latest`)
- [ ] Enable Docker Content Trust for image signing

## State & Backup

- [ ] Verify Litestream replication is active: `docker logs symbi-litestream`
- [ ] Enable GCS bucket versioning (protects against accidental deletion)
- [ ] Test backup/restore procedure: `bash desktop/scripts/backup-state.sh`
- [ ] Verify SQLite integrity: `sqlite3 symbi.db "PRAGMA integrity_check;"`

## Compliance

- [ ] Confirm audit retention meets requirements (7 years for SOX/HIPAA)
- [ ] Verify all agents have `prompt_injection_policy: "log_and_refuse"`
- [ ] Verify all agents have `data_disclosure_policy: "deny_system_prompt"`
- [ ] Review agent capability deny lists
- [ ] Document data classification for each agent's policy
