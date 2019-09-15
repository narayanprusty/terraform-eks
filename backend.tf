terraform {
  backend "s3" {
    bucket                = "402432300121-demo-default"
    workspace_key_prefix  = "shared/workspaces"
    key                   = "terraform.tfstate"
    region                = "us-east-1"
    dynamodb_table        = "402432300121-demo-default"
  }
}