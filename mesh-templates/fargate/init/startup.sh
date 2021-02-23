#!/bin/sh

ECS_IPV4=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.Networks[0].IPv4Addresses[0]')
echo "discovered IPv4 address is: " $ECS_IPV4

ENV_NAME="consulprod"
CONSUL_DIR="/consul/config"

echo "writing service file..."
echo '{
    "service": {
        "name": "counting",
        "port": 9001,
        "connect": { "sidecar_service": {} }
    }
}' >> ${CONSUL_DIR}/service-counting.json

echo "writing config file..."
echo '{
    "node_name": "counting-client-1",
    "client_addr": "0.0.0.0",
    "data_dir": "/consul/data",
    "retry_join": ["provider=aws tag_key=Name tag_value='$ENV_NAME'-consul-server"],
    "advertise_addr":' $ECS_IPV4 '
}' >> ${CONSUL_DIR}/config.json


echo "contents of $CONSUL_DIR is:"
ls ${CONSUL_DIR}

echo "reading service file..."
cat ${CONSUL_DIR}/service-counting.json

echo "reading config file..."
cat ${CONSUL_DIR}/config.json