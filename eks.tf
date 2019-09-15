/*
  Create a IAM Role and attach policies to it. 
  This IAM Role will be used by EKS to setup all AWS resources it needs to create master.
*/


resource "aws_iam_role" "eks" {
  name = "${local.name}_eks"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

/*
  These policies are required for setup of master.
*/

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks.name}"
}

/*
  Create a VPC with minimum 2 subnets in different availability zones.
  The master and worker nodes will run in this VPC
  2 subnets in 2 AZs is requied to make sure high availability of master.
*/


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = local.vpc_cidr

  azs            = local.azs
  public_subnets = local.public_subnets

  enable_nat_gateway   = false
  single_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
}


/*
  Allow all incoming traffic for the default security group of the VPC.
  This security group is for worker nodes. This also needs to be passed as a reference while creating the EKS cluster.
*/

resource "aws_security_group_rule" "allow_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = "${module.vpc.default_security_group_id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

/*
  Deploy the EKS cluster i.e., master node.

  One import thing to note is that: EKS integrates with Amazon’s account and permission services, which means that you need an AWS IAM token to call the master APIs. 
  So basically only the certificate authority data and master endpoint is not enough to connect to master APIs, we also need IAM token. Also note that the IAM should be accepted by the master. 
  The IAM we pass during EKS setup is whitelisted by default. If you want to whitelist more IAMs then you need to do that using aws-auth config map.
*/

resource "aws_eks_cluster" "cluster" {
  name     = local.name
  role_arn = "${aws_iam_role.eks.arn}"
  version  = local.k8s_version

  vpc_config {
    security_group_ids = ["${module.vpc.default_security_group_id}"]
    subnet_ids         = flatten([module.vpc.public_subnets])
  }
}

/*
  Here on we will deploy worker nodes.
  The worker nodes should scale on demand across subnets.
  Worker nodes are basically EC2 instances.
*/

/*
  We need an IAM role for the worker nodes. This is required because worker nodes needs to call other AWS resources.
  For example: worker node needs to communicate with EKS to register itself as a worker node.
  
  We can use the previous IAM role by extending it's policies and principals. But we will create a seperate one just to keep things modular.
  Also note that, even if we use the eks role we will have to whitelist it using aws-auth config map because it's neccessary for the worker node registration process that the IAM of worker has to be in aws-auth.
*/

resource "aws_iam_role" "worker" {
  name = "${local.name}_worker"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

/*
  These policies are required by worker node's IAM role.
*/

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.worker.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.worker.name}"
}

/*
  An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance when the instance starts.
*/

resource "aws_iam_instance_profile" "worker" {
  name = local.name
  role = "${aws_iam_role.worker.name}"
}

/*
  EC2 Instances Configuration
  
  user_data is used to running commands on the VMs at launch. We will run command to register the worker node in the EKS cluster..

  Also make sure you use a EKS optimized OS image i.e., it contains all the dependencies neccessary to be a worker..
*/

locals {
  userdata = <<EOF
#!/bin/bash -xe

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
echo "${aws_eks_cluster.cluster.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.cluster.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${local.name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${local.region},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.cluster.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
EOF
}

resource "aws_launch_configuration" "worker" {
  name                        = local.name
  image_id                    = local.image_id
  instance_type               = local.instance_type
  security_groups             = ["${module.vpc.default_security_group_id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.worker.name}"
  associate_public_ip_address = true
  user_data                   = "${base64encode(local.userdata)}"
  key_name                    = "xyz"

  lifecycle {
    create_before_destroy = true
  }
}

/*
  An Auto Scaling group contains a collection of Amazon EC2 instances that are treated as a logical grouping for the purposes of automatic scaling and management.
  Now we will create a auto scaling group to scale the number of worker nodes on demand therefore achieving an auto-scalable EKS cluster.
  We can launch EC2 instances directly using the aws_launch_configuration we created above but it won't scale automatically.

  Note the tags are necessary
*/

resource "aws_autoscaling_group" "worker" {
  desired_capacity     = local.desired_capacity
  launch_configuration = "${aws_launch_configuration.worker.id}"
  max_size             = local.max_size
  min_size             = local.min_size
  name                 = local.name
  vpc_zone_identifier  = flatten([module.vpc.public_subnets])

  tag {
    key                 = "Name"
    value               = "${local.name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${local.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

/*
  Finally as mentioned above, we have to specify the IAM role of the worker node in aws-auth config map so that worker node can join the cluster.
*/

data "aws_eks_cluster_auth" "worker" {
  name = local.name
}

provider "kubernetes" {
  host                   = "${aws_eks_cluster.cluster.endpoint}"
  cluster_ca_certificate = "${base64decode(aws_eks_cluster.cluster.certificate_authority.0.data)}"
  token                  = "${data.aws_eks_cluster_auth.worker.token}"
  load_config_file       = false
}

resource "kubernetes_config_map" "worker" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = <<EOF
- rolearn: ${aws_iam_role.worker.arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
EOF
  }

  depends_on = ["aws_autoscaling_group.worker"]
}