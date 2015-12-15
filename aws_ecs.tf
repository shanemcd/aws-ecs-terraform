provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

resource "aws_vpc" "ecs" {
    cidr_block = "${var.ecs_vpc_cidr}"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags {
        Name = "ECS"
    }
}

resource "aws_internet_gateway" "ecs" {
    vpc_id = "${aws_vpc.ecs.id}"
}

resource "aws_vpc" "persistent_data" {
    cidr_block = "${var.persistent_data_vpc_cidr}"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags {
        Name = "Persistent Data"
    }
}

resource "aws_vpc_peering_connection" "ecs_to_persistent" {
    vpc_id = "${aws_vpc.ecs.id}"

    peer_owner_id = "${var.vpc_peer_account_owner_id}"
    peer_vpc_id = "${aws_vpc.persistent_data.id}"

    auto_accept = true

    tags {
        Name = "ECS To Persistent"
    }
}

# Subnets

resource "aws_subnet" "ecs" {
    vpc_id = "${aws_vpc.ecs.id}"
    cidr_block = "${cidrsubnet(var.ecs_vpc_cidr, 8, 0)}"
    availability_zone = "${var.region}a"
}

resource "aws_subnet" "persistent_data_a" {
    vpc_id = "${aws_vpc.persistent_data.id}"
    cidr_block = "${cidrsubnet(var.persistent_data_vpc_cidr, 8, 0)}"
    availability_zone = "${var.region}a"
}

resource "aws_subnet" "persistent_data_b" {
    vpc_id = "${aws_vpc.persistent_data.id}"
    cidr_block = "${cidrsubnet(var.persistent_data_vpc_cidr, 8, 2)}"
    availability_zone = "${var.region}b"
}

resource "aws_subnet" "persistent_data_c" {
    vpc_id = "${aws_vpc.persistent_data.id}"
    cidr_block = "${cidrsubnet(var.persistent_data_vpc_cidr, 8, 4)}"
    availability_zone = "${var.region}c"
}

# Route Tables

resource "aws_route_table" "ecs" {
    vpc_id = "${aws_vpc.ecs.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.ecs.id}"
    }

    route {
        cidr_block = "${aws_vpc.persistent_data.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.ecs_to_persistent.id}"
    }
}

resource "aws_route_table" "persistent_data" {
    vpc_id = "${aws_vpc.persistent_data.id}"

    route {
        cidr_block = "${aws_vpc.ecs.cidr_block}"
        vpc_peering_connection_id = "${aws_vpc_peering_connection.ecs_to_persistent.id}"
    }
}

resource "aws_route_table_association" "ecs" {
    subnet_id = "${aws_subnet.ecs.id}"
    route_table_id = "${aws_route_table.ecs.id}"
}

# Route Table Associations

resource "aws_route_table_association" "persistent_data_a" {
    subnet_id = "${aws_subnet.persistent_data_a.id}"
    route_table_id = "${aws_route_table.persistent_data.id}"
}

resource "aws_route_table_association" "persistent_data_b" {
    subnet_id = "${aws_subnet.persistent_data_b.id}"
    route_table_id = "${aws_route_table.persistent_data.id}"
}

resource "aws_route_table_association" "persistent_data_c" {
    subnet_id = "${aws_subnet.persistent_data_c.id}"
    route_table_id = "${aws_route_table.persistent_data.id}"
}

# ECS Resources

resource "aws_key_pair" "ecs_instances" {
    key_name = "ecs-instances"
    public_key = "${file("keys/my_key.pub")}"
}

resource "aws_security_group" "internal_traffic" {
    name = "internal_traffic"
    description = "Allow all network local traffic."

    vpc_id = "${aws_vpc.ecs.id}"

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }

    egress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }
}

resource "aws_security_group" "ssh" {
    name = "ssh"
    description = "Allow SSH inbound"

    vpc_id = "${aws_vpc.ecs.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "http" {
    name = "http"
    description = "Allow HTTP inbound"

    vpc_id = "${aws_vpc.ecs.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "all_outbound" {
    name = "all_outbound"
    description = "Allow all outbound traffic."

    vpc_id = "${aws_vpc.ecs.id}"

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_iam_role" "ecs" {
    name = "ecs"
    assume_role_policy = "${file("policies/assume_role.json")}"
}

resource "aws_iam_instance_profile" "ecs" {
    name = "ecs"
    roles = [
        "${aws_iam_role.ecs.name}"
    ]
}

resource "aws_iam_role_policy" "ecs" {
    name = "ecs_policy"
    policy = "${file("policies/ecs.json")}"
    role = "${aws_iam_role.ecs.id}"
}

resource "template_file" "ecs_user_data" {
    template = "${file("templates/user_data.sh")}"

    vars = {
        ecs_cluster = "${var.ecs_cluster_name}"
        dockerhub_auth = "${base64encode("${var.dockerhub_username}:${var.dockerhub_password}")}"
        dockerhub_email = "${var.dockerhub_email}"
    }
}

resource "aws_launch_configuration" "ecs" {
    name_prefix = "ecs-node-"
    image_id = "${lookup(var.ecs_amis, var.region)}"
    instance_type = "t2.micro"

    associate_public_ip_address = true

    key_name = "${aws_key_pair.ecs_instances.key_name}"

    iam_instance_profile = "${aws_iam_instance_profile.ecs.name}"

    user_data = "${template_file.ecs_user_data.rendered}"

    security_groups = [
        "${aws_security_group.http.id}",
        "${aws_security_group.ssh.id}",
        "${aws_security_group.internal_traffic.id}",
        "${aws_security_group.all_outbound.id}"
    ]
}

resource "aws_elb" "ecs_elb" {
    name = "ecselb"
    security_groups = [
        "${aws_security_group.http.id}",
        "${aws_security_group.all_outbound.id}"
    ]
    subnets = ["${aws_subnet.ecs.id}"]

    listener {
        instance_port = 80
        instance_protocol = "HTTP"
        lb_port = 80
        lb_protocol = "HTTP"
    }

        health_check {
        healthy_threshold = 3
        unhealthy_threshold = 8
        timeout = 30
        target = "HTTP:80/monitor"
        interval = 60
    }
}

resource "aws_autoscaling_group" "ecs" {
    name = "ecs"
    launch_configuration = "${aws_launch_configuration.ecs.name}"

    vpc_zone_identifier = [
        "${aws_subnet.ecs.id}"
    ]

    availability_zones = [
        "${var.region}a"
    ]

    max_size = 1
    min_size = 1

    health_check_grace_period = 30
    health_check_type = "ELB"

    tag {
        key = "Name"
        value = "ecs-node"
        propagate_at_launch = true
    }
}

# RDS Resources

resource "aws_db_subnet_group" "persistent_data" {
    name = "persistent_data"
    description = "Persistent Data"

    subnet_ids = [
        "${aws_subnet.persistent_data_a.id}",
        "${aws_subnet.persistent_data_b.id}",
        "${aws_subnet.persistent_data_c.id}"
    ]
}

resource "aws_db_instance" "ecs" {
    identifier = "mydb"
    allocated_storage = 180
    backup_retention_period = 4
    engine = "postgres"
    instance_class = "db.t2.micro"
    storage_type = "gp2" # General Purpose SSD

    name = "mydb"
    username = "postgres"
    password = "password"

    db_subnet_group_name = "${aws_db_subnet_group.persistent_data.id}"
    vpc_security_group_ids = ["${aws_security_group.postgres.id}"]
    parameter_group_name = "default.postgres9.4"
}

resource "aws_security_group" "postgres" {
    name = "pg"
    description = "Allow Postgres from peering VPC"

    vpc_id = "${aws_vpc.persistent_data.id}"

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = ["${aws_vpc.ecs.cidr_block}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Elasticache Resources

resource "aws_elasticache_subnet_group" "private_subnets" {
    name = "elasticache-subnet-group"
    description = "private subnets"

    subnet_ids = [
        "${aws_subnet.persistent_data_a.id}",
        "${aws_subnet.persistent_data_b.id}",
        "${aws_subnet.persistent_data_c.id}"
    ]
}

resource "aws_elasticache_cluster" "redis" {
    cluster_id = "redis"
    engine = "redis"
    node_type = "cache.t2.micro"
    port = 6379
    num_cache_nodes = 1
    parameter_group_name = "${aws_elasticache_parameter_group.redis.name}"
    subnet_group_name = "${aws_elasticache_subnet_group.private_subnets.name}"
    security_group_ids = ["${aws_security_group.redis.id}"]
}

resource "aws_elasticache_parameter_group" "redis" {
    name = "redis-params"
    family = "redis2.8"
    description = "Redis param group"
}

resource "aws_security_group" "redis" {
    name = "redis"
    description = "Allow Redis from peering VPC"

    vpc_id = "${aws_vpc.persistent_data.id}"

    ingress {
        from_port = 6379
        to_port = 6379
        protocol = "tcp"
        cidr_blocks = ["${aws_vpc.ecs.cidr_block}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_elasticache_cluster" "memcached" {
    cluster_id = "memcached"
    engine = "memcached"
    node_type = "cache.t2.micro"
    port = 11211
    num_cache_nodes = 1
    parameter_group_name = "${aws_elasticache_parameter_group.memcached.name}"
    subnet_group_name = "${aws_elasticache_subnet_group.private_subnets.name}"
    security_group_ids = ["${aws_security_group.redis.id}"]
}

resource "aws_elasticache_parameter_group" "memcached" {
    name = "memcached-params"
    family = "memcached1.4"
    description = "Memcached param group"
}

resource "aws_security_group" "memcached" {
    name = "memcached"
    description = "Allow Memcached from peering VPC"

    vpc_id = "${aws_vpc.persistent_data.id}"

    ingress {
        from_port = 11211
        to_port = 11211
        protocol = "tcp"
        cidr_blocks = ["${aws_vpc.ecs.cidr_block}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
