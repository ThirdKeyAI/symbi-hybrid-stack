# Agent DSL Reference

Agents are defined using the Symbiont DSL (`.dsl` files). Each file declares an agent's capabilities, constraints, policies, and runtime parameters.

## Syntax

```
agent <name>(body: JSON) -> <ReturnType> {
    capabilities = ["cap1", "cap2", ...]

    constraints {
        deny_capabilities: ["denied1", "denied2", ...]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy <policy_name> {
        require: {
            audit_logging: true,
            ...
        }
        audit: {
            log_level: "info",
            include_input: true,
            include_output: true,
            retention_days: 365
        }
    }

    with memory = "ephemeral", security = "high", sandbox = "Tier1",
         timeout = 60000, max_memory_mb = 512 {
        // Agent logic description
    }
}
```

## Capabilities Reference

| Capability | Description |
|-----------|-------------|
| `agent_coordination` | Route tasks between agents |
| `task_routing` | Assign tasks based on capabilities |
| `health_monitoring` | Monitor agent and service health |
| `compliance_scanning` | Run regulatory compliance checks |
| `report_generation` | Generate structured reports |
| `chat_response` | Respond to chat messages |
| `status_reporting` | Report system status |
| `data_ingestion` | Accept and parse incoming data |
| `transformation` | Transform data between formats |
| `output_routing` | Route processed data to destinations |
| `market_analysis` | Analyze market data |
| `risk_assessment` | Assess and score risk |

## Deny Capabilities

Common capabilities to deny for security:

| Deny Capability | Reason |
|----------------|--------|
| `code_execution` | Prevent arbitrary code execution |
| `system_access` | Block system-level operations |
| `direct_data_access` | Force data access through APIs |
| `fund_transfer` | Block financial operations |
| `account_modification` | Prevent account changes |

## Runtime Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `memory` | `ephemeral`, `persistent` | Memory lifecycle |
| `security` | `low`, `medium`, `high` | Security tier |
| `sandbox` | `Tier1`, `Tier2`, `Tier3` | Isolation level |
| `timeout` | milliseconds | Max execution time |
| `max_memory_mb` | integer | Memory limit |

## Policies

Policies define compliance and audit requirements:

- `require` — Mandatory settings (audit logging, data classification, retention)
- `audit` — Logging configuration (level, input/output capture, retention)

## Constraints

- `boundary: "strict"` — Agent cannot exceed declared capabilities
- `prompt_injection_policy: "log_and_refuse"` — Log and reject injection attempts
- `data_disclosure_policy: "deny_system_prompt"` — Never reveal system prompt

## Context Compaction

Symbiont v1.5.0 includes an automatic context compaction pipeline that manages memory pressure. When context usage exceeds configured thresholds, the runtime progressively summarizes, compresses, archives, and truncates context items.

### Compaction Tiers

| Tier | Threshold | Action |
|------|-----------|--------|
| Summarize | 70% | Replace verbose items with summaries (up to `max_summary_tokens`) |
| Compress | 80% | Merge related summaries into compressed blocks |
| Archive | 85% | Move compressed blocks to persistent storage |
| Truncate | 90% | Drop oldest archived items to stay within limits |

### Configuration

Compaction is configured in `symbi.toml`:

```toml
[compaction]
enabled = true
summarize_threshold = 0.70
compress_threshold = 0.80
archive_threshold = 0.85
truncate_threshold = 0.90
max_summary_tokens = 500
min_items_to_compact = 5
```

Adjust thresholds based on your agent workloads. Lower values trigger compaction earlier, preserving more headroom at the cost of detail. `min_items_to_compact` prevents unnecessary compaction of small context sets.

## Adding a New Agent

1. Create `desktop/agents/<name>.dsl` following the syntax above
2. Run `make keygen` to issue AgentPin credentials
3. Restart the stack: `make desktop-down && make desktop-up`
