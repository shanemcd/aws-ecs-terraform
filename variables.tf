variable "access_key" {}
variable "secret_key" {}

variable "region" {}

variable "ecs_cluster_name" {}

variable "vpc_peer_account_owner_id" {}

variable ecs_amis {
    default = {
        us-east-1 = "ami-ddc7b6b7"
        us-west-1 = "ami-a39df1c3"
        us-west-2 = "ami-d74357b6"
        eu-west-1 = "ami-f1b46b82"
        ap-northeast-1 = "ami-3077525e"
        ap-southeast-1 = "ami-21ae6942"
        ap-southeast-2 = "ami-23b4eb40"
    }
}

variable "ecs_vpc_cidr" {
    default = "130.0.0.0/16"
}

variable "persistent_data_vpc_cidr" {
    default = "192.168.0.0/16"
}

variable "dockerhub_username" {}
variable "dockerhub_password" {}
variable "dockerhub_email" {}
