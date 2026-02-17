agent support_bot(body: JSON) -> Response {
    capabilities = ["chat_response", "status_reporting", "report_generation"]

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

    policy support_safety {
        require: {
            audit_logging: true,
            data_classification: "customer_facing",
            retention: "3_years"
        }
        audit: {
            log_level: "info",
            include_input: true,
            include_output: true,
            retention_days: 1095
        }
    }

    with memory = "ephemeral", security = "high", sandbox = "Tier1",
         timeout = 30000, max_memory_mb = 256 {
        // Handle customer support queries from Slack
        // Provide canned responses for common questions
        // Escalate complex issues to human operators
    }
}
