This repository contains terraform configuration file to deploy an EKS cluster.

## Bootstrap State

For multiple developers working on the config files (i.e., for parallel deployment support)  or for CI/CD (i.e., prevent state loss for every new build) we need to store the state in a remote DB so that it's synced between all.

To use s3 backend for state run the below commands to setup the AWS resources required for remote state:

```
export AWS_ACCESS_KEY_ID="<accesskey>"
export AWS_SECRET_ACCESS_KEY="<secretkey>"

terraform init state
terraform apply -auto-approve state 

# We need to pass the bucket and table names to backend.tf. As backend configuration doesn't accept variables so we will use this envsubst command to pass the values. You can only manually copy the output and populate it in backend.tf.

export BACKEND_BUCKET_NAME=`terraform output BACKEND_BUCKET_NAME`
export BACKEND_TABLE_NAME=`terraform output BACKEND_TABLE_NAME`
export BACKEND_REGION=`terraform output BACKEND_REGION`
cd ./eks && envsubst < backend.tf.tmpl > backend.tf && cd ..

# Everyone needs to use the same bucket and table names therefore we commit it
git commit -m "Backend setup completed" && git push origin master
```

> Note that this step is required once only. After the remote backend is created we don't need to bootstrap again.

## Setup Cluster

To setup EKS cluster run the following command:

```
export AWS_ACCESS_KEY_ID="<accesskey>"
export AWS_SECRET_ACCESS_KEY="<secretkey>"

# If you are running this after bootstrap then it will prompt you to migrate local state to remote backend. Approve it so that you or someone else can destroy/re-configure the existing state backend also.
terraform init eks

terraform apply -auto-approve eks 
```

## Custom Cluster Configuration

You can change the region and other cluster configuration in the local.tf file.

## kubeconfig Configuration

Run the below command to configure `kubectl` to connect to the EKS cluster:

```
export AWS_ACCESS_KEY_ID="<accesskey>"
export AWS_SECRET_ACCESS_KEY="<secretkey>"
aws eks --region us-east-1 update-kubeconfig --name demo
```

Now you should be able to use `kubectl` command.