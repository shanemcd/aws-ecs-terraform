This is a Terraform plan geared towards standing up a production-ready ECS environment. Out of the box, it will create 2 VPCs:

`ecs`: This is where your ECS cluster will run.

`persistent_data`: By default, contains a Postgres RDS instance, Redis Elasticache Cluster, and a Memcached Elasticache Cluster.

The two VPCs are connected via a [Peering Connection](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-peering.html). The RDS instance and Elasticache clusters have security groups that allow inbound traffic from the VPC your ECS cluster runs in on the appropriate ports.

The intent is for application clusters to be to decoupled from their data stores. This allows environments to be created or destroyed, while ensuring that data is kept safe and isolated.

### Getting Started:

Make sure you have the [Terraform](http://terraform.io) binaries installed and available somewhere in your `$PATH`.

#### Create and Update `terraform.tfvars`

```bash
$ cp terraform.tfvars.example terraform.tfvars
```

This file contains the following:

##### AWS Variables

- `access_key`
- `secret_key`
- `region`
- `vpc_peer_account_owner_id`
- `ecs_cluster_name`

The variable `vpc_peer_account_owner_id` is your AWS Account ID.

##### Docker Hub Variables

- `dockerhub_username`
- `dockerhub_password`
- `dockerhub_email`

These variables are Base64 encoded and inserted into the user data script used to boot up your ECS instances. This allows the ECS agent to access private Docker Hub images.

#### Generate SSH Keys

Generate a new SSH key pair and replace `keys/my_key.pub` with your new public key.

#### Execute Plan

```bash
$ terraform plan
$ terraform apply
```

Reference the [ECS Docs](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html) for info on how to create your ECS Task Definitions and Services.

