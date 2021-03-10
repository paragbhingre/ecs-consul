# Using Consul Connect service mesh with Amazon ECS Servcies on AWS Fargate

> DISCLAIMER: Guide under development, templates may not 100% work for it yet

In this walkthrough we'll configure several ECS container services running on AWS Fargate to join and communicate via a Consul Connect service mesh which is hosted on Amazon EC2.

## Requirements:
* An AWS account
* Docker


## Create the ECS Cluster and VPC

First we're going to create a VPC and an Amazon ECS cluster for our mesh and services to reside in. Make sure to select a valid key pair so you can SSH into the server instance and view the Consul UI.
```
aws cloudformation deploy --template-file ..\cluster-ec2-consul-connect.yml
--stack-name ConsulEcsCluster --parameter-overrides KeyName=yulDev --capabilities CAPABILITY_IAM --region ca-central-1
```

## Deploy the Consul Connect server

Now we're going to deploy a Consul connect server that our ECS/Fargate services can join. In production, you would want to have an odd number of redundant server instances running in order to provide more robust and resilient consensus, but one server will work for this simple example.

They we deloy the Consul service mesh server:
```
aws cloudformation deploy --template-file ..\mesh-consul-connect.yml --stack-name ConsulMeshStack --parameter-overrides KeyName=yulDev --capabilities CAPABILITY_IAM --region ca-central-1
```

At this point you should be able to SSH into your Consul server instance and access the Consul UI. The SSH command will be in the stack output and looks something like:
```
ssh -i "~/.ssh/yulDev.pem" -L 127.0.0.1:8500:ec2-3-96-158-00.ca-central-1.compute.amazonaws.com:8500 ec2-user@ec2-3-96-158-00.ca-central-1.compute.amazonaws.com
```

Navigte to `localhost:8500` in your browser and view the services and nodes in the mesh:

[IMAGE TBD]


## Launch Amazon ECS / Fargate services into the cluster

Now we're ready to launch some ECS services into the cluster! But first let's look at the makeup of the services we're about to create:

[IMAGE OF TASK TBD]

* Each service uses an `init` container to generate the Consul agent config and service definition. This container will exit when it's done.
* Our service container which needs to communicate with other services via Consul
* The Consul agent, which automatically joins the mesh based on tags
* The Consul Connect proxy which handles communcation between the service container and the Consul agent.

### Build & push the `init` containers to Amazon ECR

> TODO: add bash equivalent cmds in addition to PowerShell

Build the `init` containers for each service and push them to Amazon ECR:
(_NOTE: I'm using the `ecs-cli` to push these, since it handles repository creation & login along with the push step._)
```
docker build -f greeting/init/Dockerfile -t greeting-init greeting/init
docker build -f name/init/Dockerfile -t name-init name/init
docker build -f greeter/init/Dockerfile -t greeter-init greeter/init

ecs-cli.exe push greeting-init -r ca-central-1 
ecs-cli.exe push name-init -r ca-central-1
ecs-cli.exe push greeter-init -r ca-central-1
```

### Create the Amazon ECS services

We can now use AWS CloudFormation to create 3 Amazon ECS services

```
# set environment variables for your account's ECR URI and the agent task role 
$env:ECR_URI = "ACCOUNT_ID.dkr.ecr.ca-central-1.amazonaws.com"
$env:CONSUL_AGENT_ROLE = "ConsulMeshStack-ConsulAgentRole-2NIRVY4YBJ1E"

# deploy the "name" service
aws cloudformation deploy --template-file .\name\service-consul-connect-name-fargate.yml --stack-name ConsulNameService --parameter-overrides InitImageUrl=$env:ECR_URI/name-init Role=$env:CONSUL_AGENT_ROLE --region ca-central-1

# deploy the "greeting" service
aws cloudformation deploy --template-file .\name\service-consul-connect-greeting-fargate.yml --stack-name ConsulNameService --parameter-overrides InitImageUrl=$env:ECR_URI/greeting-init Role=$env:CONSUL_AGENT_ROLE --region ca-central-1

# deploy the "greeter" service
aws cloudformation deploy --template-file .\name\service-consul-connect-greeter-fargate.yml --stack-name ConsulNameService --parameter-overrides InitImageUrl=$env:ECR_URI/greeter-init Role=$env:CONSUL_AGENT_ROLE --region ca-central-1
```

After the services are done deploying you should be able to see them in your Consul UI:

[IMAGE TBD]