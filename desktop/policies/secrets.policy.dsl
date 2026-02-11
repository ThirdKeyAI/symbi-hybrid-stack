// Secrets access policy — controls which secrets each agent can read.

policy secrets_access {
    default: "deny"

    // LLM API keys — all agents need their provider key
    secret "OPENROUTER_API_KEY" {
        allow: ["coordinator", "compliance_checker", "chat_responder", "data_processor"]
        access: "read"
    }

    secret "OPENAI_API_KEY" {
        allow: ["coordinator", "compliance_checker", "chat_responder", "data_processor"]
        access: "read"
    }

    secret "ANTHROPIC_API_KEY" {
        allow: ["coordinator", "compliance_checker", "chat_responder", "data_processor"]
        access: "read"
    }

    // Auth token — coordinator only
    secret "SYMBI_AUTH_TOKEN" {
        allow: ["coordinator"]
        access: "read"
    }

    // Slack credentials — chat responder only
    secret "SLACK_BOT_TOKEN" {
        allow: ["chat_responder"]
        access: "read"
    }

    secret "SLACK_SIGNING_SECRET" {
        allow: ["chat_responder"]
        access: "read"
    }

    // AgentPin keys — coordinator manages identity
    secret "fleet-key-01.jwk" {
        allow: ["coordinator"]
        access: "read"
    }

    // GCS credentials — litestream only (not agent-accessible)
    secret "GCS_STATE_BUCKET" {
        allow: []
        access: "deny"
    }
}
