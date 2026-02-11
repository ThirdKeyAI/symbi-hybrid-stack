# State Sync Architecture

The hybrid stack uses **Litestream** to continuously replicate the SQLite database from the desktop to Google Cloud Storage. This enables the cloud standby to pick up where the desktop left off during failover.

## How It Works

```
Desktop (primary)                     Cloud (standby)
┌─────────────┐                       ┌─────────────┐
│   Symbi     │                       │   Symbi     │
│   SQLite DB │──► Litestream ──►     │   SQLite DB │
└─────────────┘    (continuous)  GCS  └─────────────┘
                                 ▲          │
                                 │          │
                              snapshot   restore on
                              every 1s   failover
```

## Lease-Based Coordination

Only one coordinator can be active at a time, enforced by the `coordinator_lease` table:

1. **Desktop starts**: Acquires the lease with `instance_type = 'desktop'`
2. **Desktop heartbeats**: Updates `last_heartbeat` every 10 seconds
3. **Cloud checks**: If `lease_expiry` has passed, cloud acquires the lease
4. **Desktop returns**: Reclaims the lease on next heartbeat (desktop-primary strategy)

See `lease-schema.sql` for the full schema.

## Configuration

- `sync-config.toml` — Replication settings (bucket, interval, conflict resolution)
- `desktop/litestream.yml` — Litestream daemon configuration
- `desktop/docker-compose.yml` — Litestream container shares a volume with Symbi

## Manual Backup

```bash
bash desktop/scripts/backup-state.sh
```

Creates a point-in-time snapshot and uploads it to GCS.
