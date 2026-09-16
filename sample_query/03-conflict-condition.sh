. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SQL="
SELECT *
FROM telemetry.meas
WHERE tenant='tenant-456'
ORDER BY observed_at
"

query tenant-123
query tenant-456
query tenant-789
