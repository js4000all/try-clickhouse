. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SQL="
SELECT *
FROM telemetry.v_meas_enriched
ORDER BY observed_at;
"

query tenant-123
query tenant-456
query tenant-789
