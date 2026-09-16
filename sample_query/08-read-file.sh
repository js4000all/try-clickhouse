. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SQL="
SELECT *
FROM file(
    'dictionary/metric.csv',
    'CSVWithNames',
    'metric String, display_name String'
);
"
query 

SQL="
SELECT
    m.metric,
    meta.display_name,
    m.tenant,
    m.value,
    m.observed_at,
    m.ingested_at
FROM telemetry.meas AS m
JOIN file(
    'dictionary/metric.csv',
    'CSVWithNames',
    'metric String, display_name String'
) AS meta
ON m.metric = meta.metric
ORDER BY m.observed_at;
"
query tenant-123
query tenant-456
query tenant-789
