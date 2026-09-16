#!/bin/bash
set -euo pipefail

clickhouse client \
    --user "${CLICKHOUSE_USER}" \
    --password "${CLICKHOUSE_PASSWORD}" \
    --multiquery <<SQL

CREATE DATABASE IF NOT EXISTS telemetry;

CREATE TABLE IF NOT EXISTS telemetry.meas
(
    metric LowCardinality(String),
    tenant String,
    value Float64,
    observed_at DateTime64(3),
    ingested_at DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
ORDER BY (tenant, metric, observed_at);

CREATE USER IF NOT EXISTS ${QUERY_USER}
IDENTIFIED WITH sha256_password BY '${QUERY_PASSWORD}';

GRANT SELECT ON telemetry.meas TO ${QUERY_USER};
GRANT SELECT ON telemetry.metric_meta TO ${QUERY_USER};

CREATE ROW POLICY IF NOT EXISTS tenant_isolation
ON telemetry.meas
FOR SELECT
USING tenant = getSetting('auth_tenant')
TO ${QUERY_USER};

INSERT INTO telemetry.meas
    (metric, tenant, value, observed_at)
VALUES
    ('temperature', 'tenant-123', 21.5, now64(3) - INTERVAL 5 MINUTE),
    ('temperature', 'tenant-123', 22.1, now64(3) - INTERVAL 4 MINUTE),
    ('humidity',    'tenant-123', 45.2, now64(3) - INTERVAL 3 MINUTE),

    ('temperature', 'tenant-456', 31.4, now64(3) - INTERVAL 5 MINUTE),
    ('temperature', 'tenant-456', 32.0, now64(3) - INTERVAL 4 MINUTE),
    ('humidity',    'tenant-456', 67.8, now64(3) - INTERVAL 3 MINUTE);

CREATE TABLE telemetry.metric_meta
(
    metric String,
    display_name String
)
ENGINE = MergeTree
ORDER BY metric;

INSERT INTO telemetry.metric_meta VALUES
    ('temperature', '気温'),
    ('humidity',    '湿度');

SQL
