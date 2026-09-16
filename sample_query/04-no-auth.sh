. .env
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SQL="
SELECT *
FROM telemetry.meas
ORDER BY observed_at
"

curl \
    -u ${QUERY_USER}:${QUERY_PASSWORD} \
    "http://localhost:8123/" \
    --data-binary "${SQL}"
