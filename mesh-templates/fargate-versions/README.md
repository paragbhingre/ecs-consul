# Using Consul Connect service mesh with Amazon ECS Servcies on AWS Fargate

> DISCLAIMER: Guide under development, templates may not 100% work for it yet

In this walkthrough we'll configure several ECS container services running on AWS Fargate to join and communicate via a Consul Connect service mesh which is hosted on Amazon EC2.

## Requirements:
* The AWS CLI with valid AWS account credentials configured
* Docker

**NOTE: All commands assume execution from within the root of this directory (i.e., `fargate-versions` directory). 


## Create the ECS Cluster, ECR repositories, and VPC

First we're going to create a VPC and an Amazon ECS cluster for our mesh and services to reside in. 
* NOTE: Make sure to select a valid key pair so you can SSH into the server instance and view the Consul UI later.
```
aws cloudformation deploy --template-file .\cluster-ec2-consul-connect.yml
--stack-name ConsulEcsCluster --parameter-overrides KeyName=$MY_SSH_KEY --capabilities CAPABILITY_IAM --region $AWS_REGION
```

## Deploy the Consul Connect server

Now we're going to deploy a Consul connect server that our ECS/Fargate services can join. In production, you would want to have an odd number of redundant server instances running in order to provide more robust and resilient consensus, but one server will work for this simple example.
```
aws cloudformation deploy --template-file .\mesh-consul-connect.yml --stack-name ConsulMeshStack --parameter-overrides KeyName=$MY_SSH_KEY --capabilities CAPABILITY_IAM --region $AWS_REGION
```

At this point you should be able to SSH into your Consul server instance and access the Consul UI. The SSH command will be in the stack output and looks something like:
```
ssh -i "~/.ssh/MY_KEY.pem" -L 127.0.0.1:8500:ec2-0-96-158-00.ca-central-1.compute.amazonaws.com:8500 ec2-user@ec2-0-96-158-00.ca-central-1.compute.amazonaws.com
```

Navigte to `localhost:8500` in your browser and view the services and nodes in the mesh:

[IMAGE TBD]


## Launch AWS Fargate services into your Amazon ECS cluster

Now we're ready to launch some ECS services into the cluster! But first let's look at the makeup of the services we're about to create:

[IMAGE OF TASK TBD]

Each task will be composed of 3 containers:

* Our service container which needs to communicate with other services via Consul
* The Consul client container, which generates the Consul agent config and service definition before starting the Consul client.
* The Consul Connect proxy which handles communcation between the service container and the Consul agent.

### Build & push the `init` containers to Amazon ECR

> TODO: add bash equivalent cmds in addition to PowerShell
> TODO 2: Use ECR credential helper?

Build the service containers for each service

```
docker build -f greeting/src/Dockerfile -t greeting greeting/src
docker build -f name/src/Dockerfile -t name name/src
docker build -f greeter/src/Dockerfile -t greeter greeter/src
```

Login to ECR. Make sure to use your AWS account ID and the specific region where you have been deploying the other components of the service mesh.

```
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

Push the service images to ECR
```
# save ECR registry URI to an environment variable so we can reuse it
ECR_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# tag and push the greeting service image
docker tag greeting:latest $ECR_URI/greeting:latest
docker push $ECR_URI/greeting:latest

# tag and push the name service image
docker tag name:latest $ECR_URI/name:latest
docker push $ECR_URI/name:latest

# tag and push the greeter service image
docker tag greeter:latest $ECR_URI/greeter:latest
docker push $ECR_URI/greeter:latest
```

Now build and push the Consul agent containers for each service the same way.
```
docker build -f greeting/init/Dockerfile -t greeting-init greeting/init
docker tag greeting-init:latest $ECR_URI/greeting-init:latest
docker push $ECR_URI/greeting-init:latest

docker build -f name/init/Dockerfile -t name-init name/init
docker tag name-init:latest $ECR_URI/name-init:latest
docker push $ECR_URI/name-init:latest

docker build -f greeter/init/Dockerfile -t greeter-init greeter/init
docker tag greeter-init:latest $ECR_URI/greeter-init:latest
docker push $ECR_URI/greeter-init:latest
```

### Create the Amazon ECS services

We can now use AWS CloudFormation to create the 3 Amazon ECS services

```
# deploy the "greeting" service
aws cloudformation deploy --template-file .\greeting\service-consul-connect-greeting-fargate.yml --stack-name ConsulGreetingService --parameter-overrides ImageUrl=$ECR_URI/greeting InitImageUrl=$ECR_URI/greeting-init --region $AWS_REGION

# deploy the "name" service
aws cloudformation deploy --template-file .\name\service-consul-connect-name-fargate.yml --stack-name ConsulNameService --parameter-overrides ImageUrl=$ECR_URI/name InitImageUrl=$ECR_URI/name-init --region $AWS_REGION


# deploy the "greeter" service
aws cloudformation deploy --template-file .\greeter\service-consul-connect-greeter-fargate.yml --stack-name ConsulGreeterService --parameter-overrides ImageUrl=$ECR_URI/greeter InitImageUrl=$ECR_URI/greeter-init --region $AWS_REGION
```

After the services are done deploying you should be able to see them in your Consul UI at `http://localhost:8500/ui/dc1/services`:

[IMAGE TBD]

## Deploy the Ingress service + Load Balancer

To expose the `greeter` service to the internet, we'll create an `nginx` service with a Consul client to proxy requests via the mesh, and put it behind an Application Load Balancer. 

Build and push the ingress-init container
```
docker build -f ingress/init/Dockerfile -t ingress-init ingress/init
docker tag ingress-init:latest $ECR_URI/ingress-init:latest
docker push $ECR_URI/ingress-init:latest
```

Deploy the service and ALB
```
aws cloudformation deploy --template-file .\ingress\ingress-consul-connect-fargate.yml --stack-name ConsulIngress --parameter-overrides InitImageUrl=$ECR_URI/ingress-init Role=$env:CONSUL_AGENT_ROLE --region $AWS_REGION
```

When the stack is complete, the external URL of the ALB will appear as the stack output `ExternalUrl` - curl this endpoint and you should see a response from your service(s) in the mesh.
```
curl http://consu-publi-aaauv3we8kbg-87191928.ca-central-1.elb.amazonaws.com/

# response
From ip-10-0-0-87.ca-central-1.compute.internal: Hello (ip-10-0-0-176.ca-central-1.compute.internal) Barbara (ip-10-0-1-203.ca-central-1.compute.internal)
```