. .env

docker compose exec ch \
  clickhouse-client \
  --user ${CLICKHOUSE_USER} \
  --password ${CLICKHOUSE_PASSWORD} \
  --query "
    SELECT *
    FROM telemetry.meas
    ORDER BY tenant, observed_at
  "
