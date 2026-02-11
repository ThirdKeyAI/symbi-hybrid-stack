# AgentPin Identity Model

Every agent in the fleet has a cryptographic identity provided by [AgentPin](https://agentpin.org).

## How It Works

1. **Fleet Keypair**: A single ES256 (ECDSA P-256) keypair is generated for the fleet, anchored to your domain.

2. **Per-Agent Credentials**: Each agent receives a signed JWT credential binding its `agent_id` to the fleet key. This proves the agent belongs to your organization.

3. **Trust Bundle**: A JSON file containing all public keys and agent registrations. Used for air-gapped verification without network access.

4. **Discovery**: The `.well-known/agent-identity.json` endpoint allows external parties to discover and verify your agents.

## Key Files

| File | Description | Permissions |
|------|-------------|-------------|
| `secrets/fleet-key-01.jwk` | Fleet private key (ES256) | `0600` — owner only |
| `secrets/fleet-key-01.pub.jwk` | Fleet public key | `0644` — world readable |
| `secrets/trust-bundle.json` | Trust bundle for verification | `0644` — world readable |
| `secrets/<agent>.jwt` | Per-agent credential | `0600` — owner only |

## Usage

```bash
# Generate keys (run once, or to rotate)
bash shared/identity/keygen.sh

# Verify a credential
agentpin verify --bundle secrets/trust-bundle.json --credential secrets/coordinator.jwt

# Verify via domain discovery
agentpin verify --domain yourdomain.com --agent-id coordinator
```

## Security Notes

- Private keys (`*.jwk`) must never be committed to git (covered by `.gitignore`)
- Rotate keys by running `keygen.sh` again — old credentials become invalid
- Trust bundles can be distributed out-of-band for air-gapped environments
- Only ES256 (P-256) is supported — other algorithms are rejected
