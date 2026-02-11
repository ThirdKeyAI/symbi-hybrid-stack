// Audit logging policy — what gets logged, where, and retention.

policy audit {
    // Global audit settings
    default_log_level: "info"
    format: "json"

    // Where logs are stored
    destinations {
        primary: "/var/lib/symbi/audit.log"
        stdout: true    // also emit to Docker logs
    }

    // What to log
    events {
        // Always log these
        always: [
            "agent_invocation",
            "task_assignment",
            "task_completion",
            "auth_success",
            "auth_failure",
            "policy_violation",
            "prompt_injection_attempt",
            "capability_denied",
            "health_check",
            "failover_event"
        ]

        // Log input/output for these agents
        capture_io: ["coordinator", "compliance_checker"]

        // Redact sensitive fields from logs
        redact: [
            "api_key",
            "token",
            "password",
            "secret",
            "authorization"
        ]
    }

    // Retention
    retention {
        default: "365d"
        compliance_events: "2555d"    // 7 years for SOX/HIPAA
        auth_events: "365d"
        health_events: "90d"
    }

    // Rotation
    rotation {
        max_size: "100MB"
        max_files: 10
        compress: true
    }
}
