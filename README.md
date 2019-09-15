# Deploy EKS using Terraform

This repository contains terraform configuration files to deploy an EKS cluster.

[![Build Status](https://travis-ci.org/narayanprusty/terraform-eks.svg?branch=master)](https://travis-ci.org/narayanprusty/terraform-eks)

## AWS Configuration

Before you run any of the commands in the below section make sure these environment varibales are created:

```
export AWS_ACCESS_KEY_ID="<accesskey>"
export AWS_SECRET_ACCESS_KEY="<secretkey>"
```

## Bootstrap State

For multiple developers working on the config files (i.e., for parallel deployment support) or for CI/CD (i.e., prevent state loss for every new build) we need to store the state in a remote DB so that it's synced between all.

To use s3 backend for state run the below commands to setup the AWS resources required for remote state:

```
# Clone this repo
git clone https://github.com/narayanprusty/terraform-eks.git && cd terraform-eks

# Setup the state backend

git clone https://github.com/narayanprusty/terraform-backend-s3.git && cd terraform-backend-s3
terraform init
terraform apply -auto-approve

## We need to pass the bucket and table names to backend.tf. As backend configuration doesn't accept variables so we will use this envsubst command to pass the values. You can only manually copy the output and populate it in backend.tf.
export BACKEND_BUCKET_NAME=`terraform output BACKEND_BUCKET_NAME`
export BACKEND_TABLE_NAME=`terraform output BACKEND_TABLE_NAME`
export BACKEND_REGION=`terraform output BACKEND_REGION`
cd .. && envsubst < backend.tf.tmpl > backend.tf
rm -rf terraform-backend-s3


## Everyone needs to use the same bucket and table names therefore we commit it
git commit -m "Backend state setup" && git push origin master
```

> Note that this step is required once only. After the remote backend is created we don't need to bootstrap again.

## Setup Cluster

To setup EKS cluster run the following command:

```
# Downloads modules, setups providers, configures state and so on.
terraform init

# Create development environment workspace. We can setup multiple environments such as: production, staging and so on
terraform workspace new dev || terraform workspace select dev

terraform apply -auto-approve
```

## Custom Cluster Configuration

You can change the region and other cluster configuration in the local.tf file.

## kubeconfig Configuration

Run the below command to configure `kubectl` to connect to the EKS cluster:

```
aws eks --region us-east-1 update-kubeconfig --name k8s_dev
```

Now you should be able to use `kubectl` command.