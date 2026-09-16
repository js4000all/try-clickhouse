. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SQL="
SELECT
    m.metric,
    mm.display_name,
    m.tenant,
    m.value,
    m.observed_at
FROM telemetry.meas AS m
LEFT JOIN telemetry.metric_meta AS mm
    ON m.metric = mm.metric
ORDER BY m.observed_at;
"

query tenant-123
query tenant-456
query tenant-789
