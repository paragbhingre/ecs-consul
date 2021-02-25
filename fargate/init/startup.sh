#!/bin/sh

ECS_IPV4=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.Networks[0].IPv4Addresses[0]')
echo "discovered IPv4 address is: " $ECS_IPV4

ENV_NAME="consulprod"
CONSUL_DIR="/consul/config"
# TODO: use task ID (but not full ARN, b/c contains bad chars)
# get from $(curl -s $ECS_CONTAINER_METADATA_URI | jq '.Labels["com.amazonaws.ecs.task-arn"]')
UUID=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.DockerName') # 

echo "writing service file..."
echo '{
    "service": {
        "name": "counting",
        "port": 9001,
        "connect": { 
            "sidecar_service": {
                "port": 8080
            } 
        }
    }
}' >> ${CONSUL_DIR}/service-counting.json

# Currently need to specify region. See: https://github.com/hashicorp/go-discover/issues/61
# old IP list: ["10.0.0.17","10.0.1.26","10.0.1.46"]

echo "writing config file..."
echo '{
    "node_name": '$UUID',
    "client_addr": "0.0.0.0",
    "data_dir": "/consul/data",
    "retry_join": ["provider=aws region=us-west-1 tag_key=Name tag_value=consulprod-consul-server"],
    "advertise_addr":' $ECS_IPV4 '
}' >> ${CONSUL_DIR}/config.json


echo "contents of $CONSUL_DIR is:"
ls ${CONSUL_DIR}

echo "reading service file..."
cat ${CONSUL_DIR}/service-counting.json

echo "reading config file..."
cat ${CONSUL_DIR}/config.json