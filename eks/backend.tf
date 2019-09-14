terraform {
  backend "s3" {
    bucket         = "402432300121-demo"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "402432300121-demo"
  }
}