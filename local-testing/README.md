# Local testing

Testing task defs with [`ecs-cli local`](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cmd-ecs-cli-local.html) lets you mock the [ECS task metadata endpoint](https://docs.aws.amazon.com/AmazonECS/latest/userguide/task-metadata-endpoint-v3-fargate.html), which we need to use for network introspection in the absence of EC2 instance info (e.g., on Fargate) 

