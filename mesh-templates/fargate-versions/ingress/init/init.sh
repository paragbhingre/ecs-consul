#!/bin/sh

SERVICE_NAME="greeter-ingress"  # the ECS service name
ENV_NAME="consulprod"           # the 'EnvironmentName' of the Consul service mesh to join
CONSUL_DIR="/consul/config"     # the directory where Consul expects to find conifg files

# discover other required values from the Amazon ECS metadata endpoint
ECS_IPV4=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.Networks[0].IPv4Addresses[0]')
echo "discovered IPv4 address is: " $ECS_IPV4

TASK_ARN=$(curl -s $ECS_CONTAINER_METADATA_URI | jq '.Labels["com.amazonaws.ecs.task-arn"]')
echo "discovered task ARN is: " $TASK_ARN

# extract AWS region and task ID from task ARN
TASK_ID=$(echo $TASK_ARN | awk -F'/' '{gsub("\"","",$NF)};{print $NF}')
AWS_REGION=$(echo $TASK_ARN | awk -F':' '{print $4}')

# build unique node name for the Consul agent
node_UUID=$SERVICE_NAME-$AWS_REGION-$TASK_ID

# Currently need to specify a region for auto-join to work on Amazon ECS
# See: https://github.com/hashicorp/go-discover/issues/61
echo "writing config file..."
echo '{
    "node_name": "'$node_UUID'",
    "client_addr": "0.0.0.0",
    "data_dir": "/consul/data",
    "retry_join": ["provider=aws region='$AWS_REGION' tag_key=Name tag_value='$ENV_NAME'-consul-server"],
    "advertise_addr":' $ECS_IPV4 '
}' >> ${CONSUL_DIR}/config.json


echo "contents of $CONSUL_DIR is:"
ls ${CONSUL_DIR}

echo "reading config file..."
cat ${CONSUL_DIR}/config.json