. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SQL="
SELECT
    display_name,
    avg(value)
FROM telemetry.v_meas_enriched
GROUP BY display_name;
"

query tenant-123
query tenant-456
query tenant-789
