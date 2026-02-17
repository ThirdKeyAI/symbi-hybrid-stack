agent chat_responder(body: JSON) -> Response {
    capabilities = ["chat_response", "status_reporting"]

    webhook {
        provider slack
        secret   $SLACK_SIGNING_SECRET
        path     "/hooks/slack"
        filter   ["message", "app_mention"]
    }

    constraints {
        deny_capabilities: [
            "code_execution",
            "system_access",
            "direct_data_access",
            "fund_transfer",
            "account_modification"
        ]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy chat_safety {
        require: {
            audit_logging: true,
            data_classification: "user_facing",
            retention: "1_year"
        }
        audit: {
            log_level: "info",
            include_input: true,
            include_output: true,
            retention_days: 365
        }
    }

    with memory = "ephemeral", security = "high", sandbox = "Tier1",
         timeout = 30000, max_memory_mb = 256 {
        // Handle incoming Slack/Teams webhook messages
        // Provide status reports on fleet health and task progress
        // Enforce prompt injection policy on all user inputs
    }
}
