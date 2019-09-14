This repository contains terraform configuration file to deploy an EKS cluster.

## Setup Cluster

To setup EKS cluster run the following command:

```
git clone https://github.com/narayanprusty/terraform-eks.git && cd terraform-eks
terraform init
AWS_ACCESS_KEY_ID="<accesskey>" AWS_SECRET_ACCESS_KEY="<secretkey>" terraform apply -auto-approve
```

## Custom Cluster Configuration

You can change the region and other cluster configuration in the locals.tf file.

## kubeconfig Configuration

Run the below command to configure kubeconfig to connect to the EKS cluster:

```
aws configure set aws_access_key_id <accesskey>
aws configure set aws_secret_access_key <secretkey>
aws eks --region us-east-1 update-kubeconfig --name example
```

Now you should be able to use `kubectl` command.
