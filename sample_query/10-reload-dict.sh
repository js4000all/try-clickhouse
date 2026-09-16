. .env

docker compose exec ch \
  clickhouse-client \
  --user ${CLICKHOUSE_USER} \
  --password ${CLICKHOUSE_PASSWORD} \
  --query "
    SYSTEM RELOAD DICTIONARY telemetry.metric_dict;
  "
