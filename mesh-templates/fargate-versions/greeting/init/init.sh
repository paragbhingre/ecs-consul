#!/bin/sh

SERVICE_NAME="greeting-fargate"
REGION="us-west-1"

ECS_IPV4=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.Networks[0].IPv4Addresses[0]')
echo "discovered IPv4 address is: " $ECS_IPV4

ENV_NAME="consulprod"
CONSUL_DIR="/consul/config"
# TODO: use task ID (but not full ARN, b/c contains bad chars)
UUID=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.DockerName')


echo "writing service file..."
echo '{
    "service": {
        "name": "'$SERVICE_NAME'",
        "port": 3000,
        "connect": { 
            "sidecar_service": {
                "port": 8080
            } 
        }
    }
}' >> ${CONSUL_DIR}/service-${SERVICE_NAME}.json

# Currently need to specify region. See: https://github.com/hashicorp/go-discover/issues/61
echo "writing config file..."
echo '{
    "node_name": '$UUID',
    "client_addr": "0.0.0.0",
    "data_dir": "/consul/data",
    "retry_join": ["provider=aws region='$REGION' tag_key=Name tag_value=consulprod-consul-server"],
    "advertise_addr":' $ECS_IPV4 '
}' >> ${CONSUL_DIR}/config.json


echo "contents of $CONSUL_DIR is:"
ls ${CONSUL_DIR}

echo "reading service file..."
cat ${CONSUL_DIR}/service-${SERVICE_NAME}.json

echo "reading config file..."
cat ${CONSUL_DIR}/config.json