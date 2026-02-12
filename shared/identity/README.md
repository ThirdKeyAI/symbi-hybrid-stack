# AgentPin Identity Model

Every agent in the fleet has a cryptographic identity provided by [AgentPin](https://agentpin.org).

## How It Works

1. **Fleet Keypair**: A single ES256 (ECDSA P-256) keypair is generated for the fleet, anchored to your domain.

2. **Per-Agent Credentials**: Each agent receives a signed JWT credential binding its `agent_id` to the fleet key. This proves the agent belongs to your organization.

3. **Trust Bundle**: A JSON file containing discovery documents and revocation lists. Used for air-gapped verification without network access.

4. **Discovery**: AgentPin supports five methods for discovering and verifying agent identity:

| Method | CLI flags | Use case |
|--------|-----------|----------|
| Trust bundle | `--trust-bundle <file> --credential <jwt>` | Air-gapped, enterprise, fleet-internal |
| Local file | `--discovery-dir <dir> --credential <jwt>` | CI/CD, dev, testing |
| Chain resolver | `--trust-bundle` + `--discovery-dir` combined | Layered fallbacks |
| Offline | `--offline --discovery <file> --credential <jwt>` | Fully disconnected |
| Online `.well-known` | `--credential <jwt>` (no other flags) | Public-facing agents |

5. **TOFU Key Pinning**: On first verification, the agent's public key is recorded in a pin store (`--pin-store <file>`). Future verifications reject key changes unless explicitly re-pinned.

6. **Revocation**: Three-level revocation support — per-credential, per-key, and per-issuer. Revocation documents can be distributed offline (`--revocation <file>`) or fetched from the issuer's `revocation_endpoint`.

7. **Mutual Verification**: Both parties in an agent-to-agent interaction can present and verify credentials, establishing bidirectional trust.

## Key Files

| File | Description | Permissions |
|------|-------------|-------------|
| `secrets/fleet-key-01.private.pem` | Fleet private key (ES256 PEM) | `0600` — owner only |
| `secrets/fleet-key-01.public.pem` | Fleet public key (PEM) | `0644` — world readable |
| `secrets/fleet-key-01.jwk` | Fleet private key (JWK, with `--format both`) | `0600` — owner only |
| `secrets/fleet-key-01.pub.jwk` | Fleet public key (JWK) | `0644` — world readable |
| `secrets/trust-bundle.json` | Trust bundle for verification | `0644` — world readable |
| `secrets/discovery.json` | Discovery document for the fleet | `0644` — world readable |
| `secrets/<agent>.jwt` | Per-agent credential | `0600` — owner only |
| `secrets/pin-store.json` | TOFU key pinning database | `0600` — owner only |
| `secrets/revocations.json` | Revocation document | `0644` — world readable |

## Usage

```bash
# Generate keys (run once, or to rotate)
bash shared/identity/keygen.sh

# Verify with trust bundle (air-gapped / fleet-internal)
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --credential secrets/coordinator.jwt

# Verify with trust bundle + TOFU pin store
agentpin verify \
    --trust-bundle secrets/trust-bundle.json \
    --credential secrets/coordinator.jwt \
    --pin-store secrets/pin-store.json

# Verify via local discovery directory (CI/CD, dev)
agentpin verify \
    --discovery-dir ./secrets \
    --credential secrets/coordinator.jwt

# Verify fully offline
agentpin verify \
    --offline \
    --discovery secrets/discovery.json \
    --credential secrets/coordinator.jwt

# Verify via online .well-known discovery (public-facing)
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

## Security Notes

- Private keys (`*.private.pem`, `*.jwk`) must never be committed to git (covered by `.gitignore`)
- Pin stores contain trusted key fingerprints — treat as sensitive (`0600` permissions)
- Rotate keys by running `keygen.sh` again — old credentials become invalid
- Trust bundles can be distributed out-of-band for air-gapped environments
- Only ES256 (P-256) is supported — other algorithms are rejected
- Publish revocation documents promptly when revoking credentials
- TOFU pin stores should be backed up — losing a pin store means re-pinning all keys
- AgentPin fails closed: if verification cannot complete (missing bundle, unreachable endpoint), the credential is rejected
