function query(){
    local TENANT=$1
    echo TENANT=${TENANT}
    curl \
        -u ${QUERY_USER}:${QUERY_PASSWORD} \
        "http://localhost:8123/?auth_tenant=${TENANT}" \
        --data-binary "${SQL}"
}
