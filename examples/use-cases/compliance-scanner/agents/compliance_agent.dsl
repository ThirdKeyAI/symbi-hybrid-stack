agent compliance_agent(body: JSON) -> Report {
    capabilities = ["compliance_scanning", "report_generation"]

    schedule {
        cron "0 6 * * *"
        max_jitter 300
        max_concurrent 1
    }

    memory {
        store markdown
        path  "/var/lib/symbi/memory/compliance"
        retention 2555d
    }

    constraints {
        deny_capabilities: [
            "code_execution",
            "system_access",
            "data_modification",
            "fund_transfer",
            "account_modification",
            "personal_advice"
        ]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy regulatory_compliance {
        require: {
            audit_logging: true,
            data_classification: "compliance_sensitive",
            retention: "7_years"
        }
        audit: {
            log_level: "info",
            include_input: true,
            include_output: true,
            retention_days: 2555
        }
    }

    with memory = "ephemeral", security = "high", sandbox = "Tier1",
         timeout = 600000, max_memory_mb = 1024 {
        // Scan configurations and access logs
        // Check HIPAA controls: access controls, audit trails, encryption
        // Check SOX controls: change management, access reviews, data integrity
        // Generate compliance report with findings and recommendations
    }
}
