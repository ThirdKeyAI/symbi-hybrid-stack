# symbi-hybrid-stack Development Guidelines

## Project
Turnkey hybrid deployment template for Symbiont agent fleets.
Desktop-primary (Docker Compose) with Google Cloud Run standby.
Part of the ThirdKey trust stack: SchemaPin → AgentPin → Symbiont.

## Structure
- `desktop/` — Docker Compose stack (primary runtime)
- `cloud/` — Google Cloud Run (standby/burst)
- `shared/` — Identity, state schema, agent docs shared between envs
- `security/` — Security documentation and verification scripts
- `examples/` — Migration guides and use-case templates

## Conventions
- All bash scripts: `set -euo pipefail`, env loading from root `.env`, cleanup traps
- DSL files follow Symbiont agent syntax (see `shared/agents/README.md`)
- Docker Compose uses `ghcr.io/thirdkeyai/symbi:latest` — never build from source
- Terraform for GCP provisioning (>= 1.5, Google provider >= 5.0)
- AgentPin for agent identity (ES256 only)
- `shellcheck` must pass on all `.sh` files
- `yamllint` must pass on all YAML files
- `terraform validate` must pass on `cloud/terraform/`

## Key Commands
- `make init` — first-run setup
- `make desktop-up` / `make desktop-down` — start/stop desktop stack
- `make cloud-deploy` / `make cloud-teardown` — deploy/destroy cloud
- `make verify` — health + security checks
- `make keygen` — generate AgentPin identity keys
