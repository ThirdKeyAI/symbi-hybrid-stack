# SKILLS.md — Machine-Readable Runbook

This file provides step-by-step procedures for AI agents operating on this repository.

## 1. Initialize Desktop Environment

**Prerequisites:** Docker, Docker Compose v2, Bash 4+

1. Run `make init` to perform first-run setup
2. Edit `.env` and set at least one LLM API key (`OPENROUTER_API_KEY`, `OPENAI_API_KEY`, or `ANTHROPIC_API_KEY`)
3. Set `SYMBI_AUTH_TOKEN` to a strong random value (init generates one if missing)
4. Expected output: `.env` file created, Docker images pulled, identity keys generated
5. Verify: `ls .env secrets/fleet-key-01.jwk` — both files should exist

## 2. Start Desktop Stack

**Prerequisites:** Step 1 completed

1. Run `make desktop-up`
2. Wait for health checks to pass (up to 60 seconds)
3. Expected output: Three containers running (symbi, qdrant, litestream)
4. Verify: `make verify` returns all-green health report
5. Verify: `curl -s -H "Authorization: Bearer $SYMBI_AUTH_TOKEN" http://localhost:8081/webhook` returns 200

## 3. Stop Desktop Stack

1. Run `make desktop-down`
2. Expected output: Containers stopped, tunnel terminated
3. Verify: `docker compose -f desktop/docker-compose.yml ps` shows no running containers

## 4. Deploy Cloud Standby

**Prerequisites:** Step 1, Google Cloud SDK authenticated, Terraform 1.5+

1. Copy `cloud/.env.example` to `cloud/.env`
2. Set `GCP_PROJECT_ID`, `GCP_REGION`, `GCS_STATE_BUCKET`, `ARTIFACT_REGISTRY_REPO`
3. Run `make cloud-deploy`
4. Expected output: Cloud Run services deployed, Terraform outputs shown
5. Verify: `gcloud run services list --project $GCP_PROJECT_ID` shows coordinator-standby and worker-agent

## 5. Tear Down Cloud Resources

1. Run `make cloud-teardown`
2. Confirm destruction when prompted
3. Expected output: All GCP resources destroyed
4. Verify: `gcloud run services list --project $GCP_PROJECT_ID` shows no services

## 6. Generate AgentPin Identity Keys

**Prerequisites:** `agentpin` CLI v0.2.0+ on PATH

1. Run `make keygen`
2. Expected output: Fleet keypair, per-agent credentials, and trust bundle in `secrets/`
3. Verify: `ls secrets/fleet-key-01.jwk secrets/trust-bundle.json`
4. Verify: `agentpin verify --bundle secrets/trust-bundle.json` succeeds

## 7. Add a New Agent

1. Create a new `.dsl` file in `desktop/agents/` following the pattern in `shared/agents/README.md`
2. Run `make keygen` to issue credentials for the new agent
3. Run `make desktop-down && make desktop-up` to restart with the new agent
4. Verify: Check logs with `make logs` to confirm the new agent loaded

## 8. Set Up Cloudflare Tunnel

**Prerequisites:** `cloudflared` installed, Cloudflare account

1. Copy `desktop/tunnel/config.yml.example` to `desktop/tunnel/config.yml`
2. Run `bash desktop/tunnel/setup-tunnel.sh`
3. Expected output: Tunnel created and running
4. Verify: Access your fleet via the tunnel hostname

## 9. Run Security Verification

**Prerequisites:** Desktop stack running

1. Run `bash security/verify-deployment.sh`
2. Expected output: All checks pass (auth, rejection, prompt injection, AgentPin, Litestream)
3. Review any failures and remediate per `security/hardening-checklist.md`

## 10. Manual State Backup

1. Run `bash desktop/scripts/backup-state.sh`
2. Expected output: SQLite snapshot uploaded to GCS
3. Verify: `gsutil ls gs://$GCS_STATE_BUCKET/backups/` shows the snapshot
