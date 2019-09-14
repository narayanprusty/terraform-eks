This repository contains terraform configuration file to deploy an EKS cluster.

## Setup Cluster

To setup EKS cluster run the following command:

```
git clone https://github.com/narayanprusty/terraform-eks.git && cd terraform-eks
terraform init
AWS_ACCESS_KEY_ID="<accesskey>" AWS_SECRET_ACCESS_KEY="<secretkey>" terraform apply -auto-approve
```

## Custom Configuration

You can change the region and other cluster configuration in the locals.tf file.
