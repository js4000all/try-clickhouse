. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"


SQL="
SELECT *
FROM telemetry.metric_dict;
"
query 

SQL="
SELECT
    m.metric,
    md.display_name,
    m.tenant,
    m.value,
    m.observed_at,
    m.ingested_at
FROM telemetry.meas AS m
JOIN telemetry.metric_dict md ON md.metric = m.metric
ORDER BY m.observed_at;
"
query tenant-123
query tenant-456
query tenant-789
