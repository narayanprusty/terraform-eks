locals {
  name   = "k8s_${terraform.workspace}"
  region = "us-east-1"

  k8s_version = "1.14"

  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  image_id      = "ami-0c5b63ec54dd3fc38"
  instance_type = "t2.medium"

  desired_capacity = "2"
  max_size         = "3"
  min_size         = "1"
}
