// Network egress policy — controls which external hosts each agent can reach.

policy network_egress {
    default: "deny"

    // Coordinator: needs access to LLM providers and internal services only
    agent coordinator {
        allow: [
            "api.openrouter.ai:443",
            "api.openai.com:443",
            "api.anthropic.com:443",
            "symbi-qdrant:6333"
        ]
    }

    // Compliance checker: LLM providers + compliance data sources
    agent compliance_checker {
        allow: [
            "api.openrouter.ai:443",
            "api.openai.com:443",
            "api.anthropic.com:443"
        ]
    }

    // Chat responder: LLM providers + Slack/Teams webhooks
    agent chat_responder {
        allow: [
            "api.openrouter.ai:443",
            "api.openai.com:443",
            "api.anthropic.com:443",
            "hooks.slack.com:443",
            "slack.com:443"
        ]
    }

    // Data processor: LLM providers + configured output destinations
    agent data_processor {
        allow: [
            "api.openrouter.ai:443",
            "api.openai.com:443",
            "api.anthropic.com:443"
        ]
    }
}
