agent data_processor(body: JSON) -> Result {
    capabilities = ["data_ingestion", "transformation", "output_routing"]

    webhook {
        provider custom
        secret   $SYMBI_AUTH_TOKEN
        path     "/hooks/data"
        filter   ["ingest", "transform"]
    }

    constraints {
        deny_capabilities: [
            "code_execution",
            "system_access",
            "fund_transfer",
            "account_modification",
            "personal_advice"
        ]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy data_handling {
        require: {
            audit_logging: true,
            data_classification: "business_data",
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
         timeout = 120000, max_memory_mb = 1024 {
        // Accept incoming data events via webhook
        // Transform data between formats (CSV, JSON, XML)
        // Route processed output to configured destinations
    }
}
