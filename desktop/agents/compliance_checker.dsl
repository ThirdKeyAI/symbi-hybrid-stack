agent compliance_checker(body: JSON) -> Report {
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
            "account_modification"
        ]
        boundary: "strict"
        prompt_injection_policy: "log_and_refuse"
        data_disclosure_policy: "deny_system_prompt"
    }

    policy hipaa_sox {
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

    with memory = "persistent", security = "high", sandbox = "Tier1",
         timeout = 300000, max_memory_mb = 512 {
        // Run scheduled HIPAA and SOX compliance checks (daily at 6 AM)
        // Generate compliance reports with findings and recommendations
        // Flag violations for human review
        // Persist findings history for trend analysis
    }
}
