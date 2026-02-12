# symbi-hybrid-stack

**Zero to secure agent fleet in 30 minutes.**

A turnkey template for running [Symbiont](https://symbiont.dev) agent fleets in a desktop-primary, cloud-standby topology. Your local machine runs the coordinator via Docker Compose; Google Cloud Run provides failover and burst capacity.

Part of the [ThirdKey](https://thirdkey.ai) trust stack: **SchemaPin → AgentPin → Symbiont**

```
┌─────────────────────────────────────────────────────────────────┐
│                      symbi-hybrid-stack                         │
│                                                                 │
│  ┌──────────── Desktop (primary) ────────────┐                  │
│  │                                           │                  │
│  │  Docker Compose                           │                  │
│  │  ┌─────────┐ ┌────────┐ ┌────────────┐   │                  │
│  │  │  Symbi  │ │ Qdrant │ │ Litestream │   │                  │
│  │  │ :8080/  │ │ :6333  │ │ SQLite→GCS │   │                  │
│  │  │  8081   │ │        │ │            │   │                  │
│  │  └────┬────┘ └────────┘ └────────────┘   │                  │
│  │       │                                   │                  │
│  │  ┌────┴──────────┐                        │                  │
│  │  │  Cloudflare   │                        │                  │
│  │  │  Tunnel       │ ◄── zero-trust ingress │                  │
│  │  └───────────────┘                        │                  │
│  └───────────────────────────────────────────┘                  │
│                         │                                       │
│                    state sync                                   │
│                    (Litestream)                                  │
│                         │                                       │
│  ┌──────────── Cloud (standby) ──────────────┐                  │
│  │                                           │                  │
│  │  Google Cloud Run                         │                  │
│  │  ┌──────────────┐  ┌──────────────┐       │                  │
│  │  │ Coordinator  │  │   Workers    │       │                  │
│  │  │ (min=0,      │  │ (max=10,     │       │                  │
│  │  │  standby)    │  │  Pub/Sub)    │       │                  │
│  │  └──────────────┘  └──────────────┘       │                  │
│  │                                           │                  │
│  │  Artifact Registry │ Secret Manager       │                  │
│  │  GCS State Bucket  │ Cloud Logging        │                  │
│  └───────────────────────────────────────────┘                  │
│                                                                 │
│  ┌──────────── Shared ───────────────────────┐                  │
│  │  AgentPin identity keys & trust bundles   │                  │
│  │  Agent DSL definitions                    │                  │
│  │  Lease schema for coordination            │                  │
│  └───────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Docker & Docker Compose v2
- Bash 4+
- An LLM API key (OpenRouter, OpenAI, or Anthropic)
- (Optional) [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) for zero-trust ingress
- (Optional) Google Cloud SDK + Terraform 1.5+ for cloud failover

## Quick Start — Desktop Only (5 min)

One command to clone, configure, and start your agent fleet:

```bash
curl -fsSL https://symbiont.dev/install.sh | bash
```

The installer checks prerequisites, generates an auth token, prompts for your LLM API key, pulls Docker images, and starts the stack.

**Options:**

```bash
# Install to a custom directory
curl -fsSL https://symbiont.dev/install.sh | bash -s -- --dir ~/my-fleet

# Clone and configure only, don't start services
curl -fsSL https://symbiont.dev/install.sh | bash -s -- --no-start
```

<details>
<summary>Manual setup (without the installer)</summary>

```bash
# 1. Clone and enter the repo
git clone https://github.com/thirdkeyai/symbi-hybrid-stack.git
cd symbi-hybrid-stack

# 2. Initialize environment
make init

# 3. Edit .env with your LLM API key
$EDITOR .env

# 4. Start the desktop stack
make desktop-up

# 5. Verify everything is healthy
make verify
```

</details>

Your agent fleet is now running at `http://localhost:8081`. The coordinator manages task routing, health monitoring, and audit logging.

## Add Cloud Failover (15 min)

```bash
# 1. Configure cloud environment
cp cloud/.env.example cloud/.env
$EDITOR cloud/.env   # Set GCP_PROJECT_ID, GCP_REGION, etc.

# 2. Deploy cloud standby
make cloud-deploy

# 3. Verify hybrid topology
make verify
```

The cloud coordinator starts at min-instances=0 (costs nothing at idle). Workers scale to 10 instances via Pub/Sub triggers. Litestream keeps state synchronized between desktop and cloud.

## Scale Up (5 min)

Add new agents by creating DSL files in `desktop/agents/`:

```bash
# 1. Create a new agent
cp desktop/agents/data_processor.dsl desktop/agents/my_agent.dsl
$EDITOR desktop/agents/my_agent.dsl

# 2. Generate AgentPin credentials
make keygen

# 3. Restart to pick up changes
make desktop-down && make desktop-up
```

See `shared/agents/README.md` for the DSL capabilities reference.

## Project Structure

```
├── desktop/              # Docker Compose stack (primary)
│   ├── agents/           # Agent DSL definitions
│   ├── policies/         # Network, secrets, audit policies
│   ├── scripts/          # init, healthcheck, backup, stop
│   └── tunnel/           # Cloudflare Tunnel config
├── cloud/                # Google Cloud Run (standby)
│   ├── coordinator-standby/  # Standby coordinator service
│   ├── worker-agent/         # Burst worker service
│   ├── terraform/            # Infrastructure as code
│   └── scripts/              # deploy, failover, teardown
├── shared/               # Shared between desktop & cloud
│   ├── identity/         # AgentPin keys & trust bundles
│   ├── state/            # SQLite schema & sync config
│   └── agents/           # DSL documentation
├── security/             # Security docs & verification
├── examples/             # Migration guides & use cases
└── .github/              # CI/CD workflows
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make init` | First-run setup: copy .env, generate keys, pull images |
| `make desktop-up` | Start desktop Docker Compose stack |
| `make desktop-down` | Stop desktop stack gracefully |
| `make cloud-deploy` | Deploy cloud standby via Terraform |
| `make cloud-teardown` | Destroy cloud resources |
| `make verify` | Run health checks and security validation |
| `make keygen` | Generate/rotate AgentPin identity keys |
| `make logs` | Tail logs from all services |

## Security Model

Every agent in the fleet has a cryptographic identity via [AgentPin](https://agentpin.org):

- **ES256 keypairs** with five discovery methods: trust bundles, local directories, chain resolvers, offline mode, and online `.well-known` endpoints
- **TOFU key pinning** records public keys on first contact and rejects unexpected changes
- **Three-level revocation** — per-credential, per-key, per-issuer — with offline and online distribution
- **Trust bundles** for air-gapped and enterprise verification
- **Audit logging** of all agent actions with credential chains
- **Policy DSL** for network egress, secret access, and audit rules

See `security/SECURITY.md` for the full trust model and `security/threat-model.md` for the threat matrix.

## License

MIT — Copyright (c) 2025-2026 ThirdKey.ai / Tarnover, LLC
