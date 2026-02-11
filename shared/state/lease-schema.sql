-- Lease-based coordination schema for hybrid desktop/cloud topology.
-- Only one coordinator holds the lease at a time. The desktop instance
-- is primary; cloud standby acquires the lease only when the desktop
-- fails to heartbeat within the expiry window.

CREATE TABLE IF NOT EXISTS coordinator_lease (
    id           INTEGER PRIMARY KEY CHECK (id = 1),  -- singleton row
    leader_id    TEXT    NOT NULL,                      -- e.g. "desktop-01" or "cloud-run-abc123"
    instance_type TEXT   NOT NULL CHECK (instance_type IN ('desktop', 'cloud')),
    lease_expiry  TEXT   NOT NULL,                      -- ISO 8601 timestamp
    last_heartbeat TEXT  NOT NULL,                      -- ISO 8601 timestamp
    acquired_at   TEXT   NOT NULL,                      -- ISO 8601 timestamp
    metadata      TEXT                                  -- optional JSON blob
);

-- Index for quick expiry checks
CREATE INDEX IF NOT EXISTS idx_lease_expiry ON coordinator_lease(lease_expiry);

-- Heartbeat history for audit trail
CREATE TABLE IF NOT EXISTS heartbeat_log (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    leader_id     TEXT    NOT NULL,
    instance_type TEXT    NOT NULL,
    heartbeat_at  TEXT    NOT NULL,  -- ISO 8601 timestamp
    status        TEXT    NOT NULL CHECK (status IN ('ok', 'missed', 'failover'))
);

CREATE INDEX IF NOT EXISTS idx_heartbeat_leader ON heartbeat_log(leader_id, heartbeat_at);
