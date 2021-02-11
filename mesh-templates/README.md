## Creating a sample mesh

Truncated version of instructions found in [this](https://containersonaws.com/architecture/consul-connect-service-mesh/) wonderful sample architecture from [Nathan Peck](https://twitter.com/intent/user?screen_name=nathankpeck). 


1. create the EC2 cluster
```
 aws cloudformation deploy --template-file cluster-ec2-consul-connect.yml --region us-west-1 --stack-name ConsulGreeterServiceFARGATE --capabilities CAPABILITY_IAM
```
2. create the mesh server (ec2 instance) & agents (daemon service)
```
 aws cloudformation deploy --template-file mesh-consul-connect.yml --region us-west-1 --stack-name ConsulGreeterServiceFARGATE --capabilities CAPABILITY_IAM
```
3. create the `greeting` service
```
 aws cloudformation deploy --template-file service-consul-connect-greeting.yml --region us-west-1 --stack-name ConsulGreeterServiceFARGATE --capabilities CAPABILITY_IAM
```
4. create the `name` service
```
 aws cloudformation deploy --template-file service-consul-connect-name.yml --region us-west-1 --stack-name ConsulGreeterServiceFARGATE --capabilities CAPABILITY_IAM
```
5. create the `greeter` service
```
 aws cloudformation deploy --template-file service-consul-connect-greeter.yml --region us-west-1 --stack-name ConsulGreeterServiceFARGATE --capabilities CAPABILITY_IAM
```