# Migrating from LangChain to Symbiont

This guide maps LangChain patterns to Symbiont equivalents.

## Concept Mapping

| LangChain | Symbiont | Notes |
|-----------|----------|-------|
| Chain | Agent `.dsl` file | Single agent definition replaces chain composition |
| Tool | Capability | Declared in `capabilities` list |
| Memory | `memory` parameter | `"ephemeral"` or `"persistent"` |
| Agent executor | Coordinator agent | Built-in task routing and coordination |
| Output parser | Return type | `-> Report`, `-> Result`, `-> Response` |
| Callback handler | `policy` audit block | Structured audit logging |
| Vector store | Qdrant (bundled) | Qdrant runs as a service in Docker Compose |
| `.env` / `dotenv` | `.env` + `symbi.toml` | Environment for secrets, TOML for config |

## Before: LangChain Chain

```python
from langchain.chains import LLMChain
from langchain.tools import Tool
from langchain.memory import ConversationBufferMemory

tools = [
    Tool(name="search", func=search_api, description="Search the web"),
    Tool(name="calculator", func=calculator, description="Math operations"),
]

memory = ConversationBufferMemory()
agent = initialize_agent(tools, llm, memory=memory, agent_type="zero-shot")
result = agent.run("Analyze Q4 revenue trends")
```

## After: Symbiont Agent

```
agent analyst(body: JSON) -> Report {
    capabilities = ["market_analysis", "data_ingestion"]

    constraints {
        deny_capabilities: ["code_execution", "system_access"]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy compliance {
        require: { audit_logging: true }
        audit: { log_level: "info", include_input: true, include_output: true }
    }

    with memory = "ephemeral", security = "high", sandbox = "Tier1",
         timeout = 60000, max_memory_mb = 512 {
        // Analyze revenue trends from provided data
    }
}
```

Invoke via HTTP:

```bash
curl -X POST http://localhost:8081/webhook \
  -H "Authorization: Bearer $SYMBI_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task": "Analyze Q4 revenue trends", "data": {...}}'
```

## Key Differences

### Tools → Capabilities
LangChain tools are arbitrary functions. Symbiont capabilities are declared permissions — the runtime enforces what an agent can and cannot do. You don't wire up functions; you declare intent.

### Chains → Single Agents
LangChain chains compose multiple steps. In Symbiont, each agent handles its own workflow. For multi-step pipelines, the coordinator routes between agents.

### Memory → Runtime-Managed
LangChain memory is application-managed. Symbiont manages memory per the `memory` parameter — `"ephemeral"` clears after each invocation, `"persistent"` retains across calls.

### Callbacks → Audit Policies
LangChain callbacks are opt-in code hooks. Symbiont audit policies are declarative and enforced by the runtime — you can't bypass them.

## Migration Steps

1. For each LangChain chain/agent, create a `.dsl` file in `desktop/agents/`
2. Map tools to capabilities (see `shared/agents/README.md`)
3. Replace `ConversationBufferMemory` with `memory = "persistent"` if needed
4. Move API keys from application code to `.env`
5. Replace direct LLM calls with HTTP requests to the Symbi endpoint
6. Run `make init && make desktop-up` to start the stack
