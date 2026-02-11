agent pipeline_agent(body: JSON) -> Result {
    capabilities = ["data_ingestion", "transformation", "output_routing"]

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

    policy pipeline_audit {
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
         timeout = 300000, max_memory_mb = 1024 {
        // Ingest data from webhook payload (CSV, JSON, XML)
        // Transform to target format
        // Route output to configured destination (GCS, webhook, database)
    }
}
