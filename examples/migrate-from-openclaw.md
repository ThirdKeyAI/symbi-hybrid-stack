# Migrating from OpenClaw to Symbiont

This guide maps OpenClaw concepts to their Symbiont equivalents and walks through the migration.

## Concept Mapping

| OpenClaw | Symbiont | Notes |
|----------|----------|-------|
| Agent class | `.dsl` file | Declarative agent definition with capabilities |
| Tool binding | `capabilities` list | Built-in capability system, no external tool registry |
| Shared API key | Per-agent AgentPin credential | ES256 cryptographic identity per agent |
| Trust config | `constraints` block | Deny lists, prompt injection policy, boundary enforcement |
| Logging | `policy` block + audit DSL | Structured audit with configurable retention |
| Runtime config | `symbi.toml` | Single TOML file for all runtime settings |
| Agent orchestration | Coordinator agent | Dedicated coordinator with `agent_coordination` capability |
| Environment vars | `.env` + Secret Manager | Desktop `.env`, cloud Secret Manager |

## Before: OpenClaw Agent

```python
class DataProcessor(Agent):
    tools = ["csv_reader", "json_writer", "http_client"]
    api_key = os.environ["OPENAI_API_KEY"]

    def process(self, data):
        result = self.llm.complete(data)
        return self.tools.json_writer.write(result)
```

## After: Symbiont Agent

```
agent data_processor(body: JSON) -> Result {
    capabilities = ["data_ingestion", "transformation", "output_routing"]

    constraints {
        deny_capabilities: ["code_execution", "system_access"]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy data_handling {
        require: { audit_logging: true }
        audit: { log_level: "info", include_input: true, include_output: true }
    }

    with memory = "ephemeral", security = "high", sandbox = "Tier1" {
        // Transform data between formats
    }
}
```

## What You Gain

- **Cryptographic identity**: Each agent has verifiable credentials (not just shared API keys)
- **Policy enforcement**: Deny lists are enforced by the runtime, not by convention
- **Audit trail**: Structured, immutable audit logging with compliance-grade retention
- **Prompt injection defense**: Built-in detection and refusal
- **Network isolation**: Per-agent egress rules
- **Hybrid deployment**: Desktop + cloud failover out of the box

## What Changes

- **No arbitrary code execution**: Agents declare capabilities, not tools
- **No shared state by default**: Agents are isolated; use the coordinator for inter-agent communication
- **Configuration is declarative**: DSL files instead of Python classes
- **Runtime manages LLM calls**: You don't call the LLM directly; the runtime handles it

## Migration Steps

1. For each OpenClaw agent, create a `.dsl` file in `desktop/agents/`
2. Map tools to capabilities (see `shared/agents/README.md`)
3. Add deny lists for capabilities the agent should never have
4. Move API keys from agent code to `.env`
5. Run `make keygen` to generate AgentPin credentials
6. Start the stack: `make desktop-up`
7. Test with `make verify`
