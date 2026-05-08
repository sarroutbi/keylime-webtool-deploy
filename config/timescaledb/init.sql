-- Initial schema for the Keylime Monitoring Dashboard.
-- Executed once when the TimescaleDB container is first started.

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- -------------------------------------------------------------------
-- Attestation events hypertable
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS attestation_events (
    time           TIMESTAMPTZ    NOT NULL,
    agent_id       TEXT           NOT NULL,
    verifier_id    TEXT           NOT NULL,
    status         TEXT           NOT NULL,
    hash_alg       TEXT,
    enc_alg        TEXT,
    sign_alg       TEXT,
    severity       TEXT           NOT NULL DEFAULT 'info',
    details        JSONB
);

SELECT create_hypertable(
    'attestation_events',
    by_range('time'),
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_attestation_agent
    ON attestation_events (agent_id, time DESC);

CREATE INDEX IF NOT EXISTS idx_attestation_status
    ON attestation_events (status, time DESC);

-- -------------------------------------------------------------------
-- Agent state snapshots (latest known state per agent)
-- -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent_snapshots (
    agent_id       TEXT        PRIMARY KEY,
    last_seen      TIMESTAMPTZ NOT NULL,
    status         TEXT        NOT NULL,
    ip             TEXT,
    port           INTEGER,
    regcount       INTEGER,
    operational_state TEXT,
    metadata       JSONB
);

-- -------------------------------------------------------------------
-- Retention policy: drop attestation data older than 90 days
-- -------------------------------------------------------------------
SELECT add_retention_policy(
    'attestation_events',
    INTERVAL '90 days',
    if_not_exists => TRUE
);
