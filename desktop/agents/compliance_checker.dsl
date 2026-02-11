agent compliance_checker(body: JSON) -> Report {
    capabilities = ["compliance_scanning", "report_generation"]

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

    with memory = "ephemeral", security = "high", sandbox = "Tier1",
         timeout = 300000, max_memory_mb = 512 {
        // Run scheduled HIPAA and SOX compliance checks
        // Generate compliance reports with findings and recommendations
        // Flag violations for human review
    }
}
